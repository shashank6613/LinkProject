/*
  backend/index.js
  - Uses AWS Secrets Manager to load RDS credentials
  - Implements a caching layer so multiple calls only perform one Secrets Manager fetch
  - Creates pg.Pool for primary and read-replica using the fetched credentials
  - Maintains the same HTTP endpoints as your original file

  Environment variables expected:
    - SECRET_ID            : the Secrets Manager secret name or ARN (required)
    - AWS_REGION           : AWS region (default: us-west-2)
    - CACHE_TTL_SECONDS    : how many seconds to keep the secret in cache before re-fetch (default: 300)
    - DB_HOST_PRIMARY      : optional override for primary host (if secret doesn't contain it)
    - DB_HOST_REPLICA      : optional override for replica host
    - PORT                 : server port (default: 5000)

  IAM permissions required for the running role/user:
    - secretsmanager:GetSecretValue
    - kms:Decrypt (if the secret is encrypted with a KMS key you don't have implicit access to)
*/

const express = require('express');
const { Pool } = require('pg');
const bodyParser = require('body-parser');
const cors = require('cors');
require('dotenv').config();

const AWS = require('aws-sdk');

const app = express();
app.use(bodyParser.json());
app.use(cors());

// Config
const SECRET_ID = process.env.SECRET_ID; // required
const AWS_REGION = process.env.AWS_REGION || 'us-west-2';
const CACHE_TTL_SECONDS = parseInt(process.env.CACHE_TTL_SECONDS || '600', 10); // default 10 minutes
const PORT = process.env.PORT || 5000;

if (!SECRET_ID) {
  console.error('ERROR: SECRET_ID environment variable is required.');
  process.exit(1);
}

AWS.config.update({ region: AWS_REGION });
const secretsClient = new AWS.SecretsManager({ apiVersion: '2017-10-17' });

// Caching layer for Secrets Manager
let cachedSecret = null;           // { creds: { user, password, dbname, hostPrimary, hostReplica, port }, fetchedAt }
let cachedPromise = null;          // if a fetch is already in-flight, reuse this promise

async function fetchSecretFromAWS() {
  const params = { SecretId: SECRET_ID };
  const data = await secretsClient.getSecretValue(params).promise();

  if (!data || (!data.SecretString && !data.SecretBinary)) {
    throw new Error('SecretManager returned empty secret');
  }

  let secretString = data.SecretString;
  if (!secretString && data.SecretBinary) {
    // secretBinary is a Buffer (base64-encoded)
    secretString = Buffer.from(data.SecretBinary, 'base64').toString('utf-8');
  }

  let parsed = {};
  try {
    parsed = JSON.parse(secretString);
  } catch (e) {
    throw new Error('Secrets Manager secret string is not valid JSON');
  }

  // Expected JSON shape: { username, password, dbname, hostPrimary?, hostReplica?, port? }
  const creds = {
    user: parsed.username || parsed.user || parsed.db_user || parsed.dbUsername,
    password: parsed.password || parsed.pass || parsed.db_password || parsed.dbPassword,
    database: parsed.dbname || parsed.database || parsed.db_name,
    hostPrimary: parsed.hostPrimary || parsed.host || parsed.host_primary || process.env.DB_HOST_PRIMARY,
    hostReplica: parsed.hostReplica || parsed.readReplicaHost || parsed.host_replica || process.env.DB_HOST_REPLICA,
    port: parsed.port || parsed.db_port || process.env.DB_PORT || 5432
  };

  if (!creds.user || !creds.password || !creds.database || !creds.hostPrimary) {
    throw new Error('Missing required DB credentials/hosts in the secret. Secret must include user, password, database and hostPrimary (or set DB_HOST_PRIMARY env var).');
  }

  return { creds, fetchedAt: Date.now() };
}

async function getCachedSecret() {
  // If cached and not expired, return it
  if (cachedSecret) {
    const ageSec = (Date.now() - cachedSecret.fetchedAt) / 1000;
    if (ageSec < CACHE_TTL_SECONDS) {
      return cachedSecret.creds;
    }
  }

  // If a fetch is already in-flight, wait for it
  if (cachedPromise) {
    const resolved = await cachedPromise;
    return resolved.creds;
  }

  // Otherwise, fetch and cache
  cachedPromise = fetchSecretFromAWS()
    .then((s) => {
      cachedSecret = s;
      cachedPromise = null;
      return s;
    })
    .catch((err) => {
      cachedPromise = null;
      throw err;
    });

  const result = await cachedPromise;
  return result.creds;
}

// Helper to create pools once we have credentials
let primaryPool = null;
let readReplicaPool = null;

async function createPoolsUsingSecrets() {
  const creds = await getCachedSecret();

  // allow environment overrides for hostnames
  const primaryHost = process.env.DB_HOST || creds.hostPrimary;
  const replicaHost = process.env.READ_REPLICA_HOST || creds.hostReplica || creds.hostPrimary;

  // Create connection pools (reuse across application lifetime)
  primaryPool = new Pool({
    host: primaryHost,
    user: creds.user,
    port: creds.port,
    password: creds.password,
    database: creds.database
  });

  readReplicaPool = new Pool({
    host: replicaHost,
    user: creds.user,
    port: creds.port,
    password: creds.password,
    database: creds.database
  });

  // verify connections
  await primaryPool.connect();
  await readReplicaPool.connect();
}

// Initialize everything (fetch secret once and create pools)
async function init() {
  try {
    await createPoolsUsingSecrets();
    console.log('Connected to primary and replica using Secrets Manager credentials');

    // Create table if missing (on primary)
    const createTableQuery = `
        CREATE TABLE IF NOT EXISTS "users" (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            age INT NOT NULL,
            mobile VARCHAR(15) NOT NULL UNIQUE,
            place VARCHAR(50),
            amount INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );`;

    await primaryPool.query(createTableQuery);
    console.log('Table "users" created or already exists in the primary DB');

    // Start server
    app.listen(PORT, () => {
      console.log(`Server is running on port ${PORT}`);
    });

  } catch (err) {
    console.error('Initialization failed:', err);
    process.exit(1);
  }
}

// Middleware and routes (same behavior as your original file)
app.post('/api/data', async (req, res) => {
  const { name, age, mobile, place, amount } = req.body;
  if (!name || !age || !mobile || !place || !amount) {
    return res.status(400).json({ message: 'All fields are required.' });
  }

  const insertQuery = `
        INSERT INTO "users" (name, age, mobile, place, amount)
        VALUES ($1, $2, $3, $4, $5) RETURNING id`;

  try {
    const result = await primaryPool.query(insertQuery, [name, age, mobile, place, amount]);
    res.status(200).json({ success: true, message: 'User information submitted successfully!', userId: result.rows[0].id });
  } catch (err) {
    console.error('Error inserting data:', err);
    res.status(500).json({ message: 'Error inserting data.' });
  }
});

app.get('/api/search', async (req, res) => {
  const { name, mobile } = req.query;
  const sql = 'SELECT * FROM users WHERE name = $1 OR mobile = $2';

  try {
    const results = await readReplicaPool.query(sql, [name, mobile]);
    if (results.rows.length > 0) {
      res.json(results.rows);
    } else {
      res.status(404).json({ message: 'User not found' });
    }
  } catch (err) {
    console.error('Error executing query on read replica:', err.stack);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

// Custom error handler
app.use((err, req, res, next) => {
  console.error('Unexpected error:', err);
  res.status(500).json({ message: 'An unexpected error occurred.' });
});

// Optional: expose an endpoint to force-refresh the secret (useful for debugging or manual rotation)
app.post('/_admin/refresh-secret', async (req, res) => {
  try {
    // clear cache and re-create pools
    cachedSecret = null;
    if (primaryPool) await primaryPool.end();
    if (readReplicaPool) await readReplicaPool.end();

    await createPoolsUsingSecrets();
    res.json({ refreshed: true });
  } catch (err) {
    console.error('Failed to refresh secret:', err);
    res.status(500).json({ refreshed: false, error: err.message });
  }
});

// Kick off initialization
init();

