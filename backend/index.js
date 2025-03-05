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

primaryPool.connect((err) => {
    if (err) {
        console.error('Failed to connect to the primary database:', err);
        process.exit(1); // Exit the application with failure code
    }
    console.log('Connected to primary database');

    // Create table if not exists (on primary database)
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

    primaryPool.query(createTableQuery, (err, result) => {
        if (err) {
            console.error('Error creating table:', err);
            process.exit(1); // Exit the application with failure code
        }
        console.log('Table "users" created or already exists');
    });
});

// Route to handle form submissions (write to primary DB)
app.post('/api/data', (req, res) => {
    const { name, age, mobile, place, amount } = req.body;

    // Basic validation
    if (!name || !age || !mobile || !place || !amount) {
        return res.status(400).json({ message: 'All fields are required.' });
    }

    // SQL query to insert data into the user table (on primary DB)
    const insertQuery = `
    INSERT INTO "users" (name, age, mobile, place, amount)
    VALUES ($1, $2, $3, $4, $5)`;

    primaryPool.query(insertQuery, [name, age, mobile, place, amount], (err, result) => {
        if (err) {
            console.error('Error inserting data:', err);
            return res.status(500).json({ message: 'Error inserting data.' });
        }
        res.status(200).json({ success: true, message: 'User information submitted successfully!' });
    });
});

// Search endpoint (reads from the read replica DB)
app.get('/api/search', (req, res) => {
    const { name, mobile } = req.query;
    const sql = 'SELECT * FROM users WHERE name = $1 OR mobile = $2';

    readReplicaPool.query(sql, [name, mobile], (err, results) => {
        if (err) {
            console.error('Error executing query on read replica:', err.stack);
            return res.status(500).json({ message: 'Internal Server Error' });
        }
        if (results.rows.length > 0) {
            // Corrected line: Access the rows property
            res.json(results.rows);
        } else {
            res.status(404).json({ message: 'User not found' });
        }
    });
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
