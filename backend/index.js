const express = require('express');

const { Client } = require('pg');

const cors = require('cors');

const app = express();

const port = 5000;

require('dotenv').config();

const dbHost = process.env.DB_HOST;
const dbUser = process.env.DB_USER;
const dbPass = process.env.DB_PASSWORD;

console.log(dbHost);


// Enable CORS and parse JSON bodies
const corsOptions = {
          origin: 'http://localhost',  // Allow only the frontend's domain
          methods: 'GET,POST',
          allowedHeaders: 'Content-Type',
};


app.use(cors(corsOptions));

app.use(express.json());



// PostgreSQL connection details

const client = new Client({

  host: process.env.DB_HOST || 'postgres',    // PostgreSQL is running locally

  port: 5432,  // The default PostgreSQL port

  user: process.env.DB_USER || 'shank',    // Defined in docker-compose.yml (Postgres user)

  password: process.env.DB_PASSWORD || 'admin12345',    // Defined in docker-compose.yml (Postgres password)

  database: process.env.DB_NAME || 'primarydb',     // Defined in docker-compose.yml (Postgres database name)

});



// Connect to the PostgreSQL database

client.connect()

  .then(() => {

    console.log('Connected to PostgreSQL');

  })

  .catch(err => {

    console.error('Error connecting to PostgreSQL', err.stack);

  });



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

    res.json(result.rows);  // Return the matched users

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

    res.json({ success: true, user: result.rows[0] });  // Return inserted user data

  } catch (err) {

    res.status(500).json({ success: false, error: 'Failed to insert user' });

  }

});

app.get('/', (req, res) => {
          res.send('Welcome to the backend API!');
});

// Start the Express server

app.listen(port, () => {

  console.log(`Backend API is listening on port ${port}`);

});
