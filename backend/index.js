const express = require('express');
const { Pool } = require('pg');
const bodyParser = require('body-parser');
const cors = require('cors');
require('dotenv').config();  // Ensure you load environment variables

const app = express();

// Middleware
app.use(bodyParser.json()); // For parsing application/json
app.use(cors()); // Enable CORS

// PostgreSQL connection for the primary (write) database
const primaryPool = new Pool({
    host: process.env.DB_HOST || 'myprimarypgdb.clushmnnhufs.us-west-2.rds.amazonaws.com',
    user: process.env.DB_USER || 'shank',
    port: process.env.DB_PORT || 5432,
    password: process.env.DB_PASSWORD || 'admin12345',
    database: process.env.DB_NAME || 'primarydb'
});

// PostgreSQL connection for the read replica database
const readReplicaPool = new Pool({
    host: process.env.READ_REPLICA_HOST || 'myreplicapgdb.clushmnnhufs.us-west-2.rds.amazonaws.com',
    user: process.env.DB_USER || 'shank',
    port: process.env.DB_PORT || 5432,
    password: process.env.DB_PASSWORD || 'admin12345',
    database: process.env.DB_NAME || 'primarydb'
});

// Connection check to ensure both databases are up
const connectToDB = async () => {
    try {
        await primaryPool.connect();
        await readReplicaPool.connect();
        console.log('Connected to both primary and replica databases');
    } catch (err) {
        console.error('Database connection failed:', err);
        process.exit(1);
    }
};
connectToDB();

// Create the table in the primary DB if it doesn't exist
const createTable = async () => {
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

    try {
        await primaryPool.query(createTableQuery);
        console.log('Table "users" created or already exists in the primary DB');
    } catch (err) {
        console.error('Error creating table:', err);
        process.exit(1);
    }
};
createTable();

// Route to handle form submissions (write to primary DB)
app.post('/api/data', async (req, res) => {
    const { name, age, mobile, place, amount } = req.body;

    // Basic validation
    if (!name || !age || !mobile || !place || !amount) {
        return res.status(400).json({ message: 'All fields are required.' });
    }

    // SQL query to insert data into the user table (on primary DB)
    const insertQuery = `
        INSERT INTO "users" (name, age, mobile, place, amount)
        VALUES ($1, $2, $3, $4, $5) RETURNING id`;

    try {
        const result = await primaryPool.query(insertQuery, [name, age, mobile, place, amount]);
        res.status(200).json({
            success: true,
            message: 'User information submitted successfully!',
            userId: result.rows[0].id
        });
    } catch (err) {
        console.error('Error inserting data:', err);
        res.status(500).json({ message: 'Error inserting data.' });
    }
});

// Search endpoint (reads from the read replica DB)
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

// Custom error handler middleware
app.use((err, req, res, next) => {
    console.error('Unexpected error:', err);
    res.status(500).json({ message: 'An unexpected error occurred.' });
});

// Start the server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
