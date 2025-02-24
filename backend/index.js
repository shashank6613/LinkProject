const express = require('express');
const { Client } = require('pg');
const cors = require('cors');  // Importing the CORS library
const app = express();
const port = 5000;

app.use(cors());  // Enable CORS for all origins
app.use(express.json());  // For parsing application/json

// PostgreSQL connection details
const client = new Client({
  host: process.env.DB_HOST || 'myprimarypgdb.cic6t2lbg4qh.us-east-1.rds.amazonaws.com',  // Replace with your actual RDS endpoint
  port: 5432,
  user: process.env.DB_USER || 'shank',      // Replace with your actual RDS username
  password: process.env.DB_PASS || 'admin12345',  // Replace with your actual RDS password
  database: process.env.DB_NAME || 'primarydb', // Replace with your actual database name
});

client.connect();

// Create table if it doesn't exist
const createTableQuery = `
  CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    age INT,
    mobile VARCHAR(20),
    place VARCHAR(100),
    amount DECIMAL(10, 2)
  );
`;

client.query(createTableQuery, (err, res) => {
  if (err) {
    console.error('Error creating table:', err.stack);
  } else {
    console.log('Table "users" is ready or already exists.');
  }
});

// Endpoint to get users (search functionality)
app.get('/api/search', async (req, res) => {
  const { name, mobile } = req.query;  // Only searching by name or mobile

  let query = 'SELECT * FROM users WHERE 1=1';
  let params = [];

  if (name) {
    query += ' AND name ILIKE $' + (params.length + 1);
    params.push(`%${name}%`);
  }
  if (mobile) {
    query += ' AND mobile ILIKE $' + (params.length + 1);
    params.push(`%${mobile}%`);
  }

  try {
    const result = await client.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch search results' });
  }
});

// Endpoint to create a new user
app.post('/api/data', async (req, res) => {
  const { name, age, mobile, place, amount } = req.body;

  try {
    const result = await client.query(
      'INSERT INTO users (name, age, mobile, place, amount) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [name, age, mobile, place, amount]
    );
    res.json({ success: true, user: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to insert user' });
  }
});

app.listen(port, () => {
  console.log(`Backend API is listening on port ${port}`);
});
