import React, { useState } from "react";

const SearchPage = () => {
  const [searchParams, setSearchParams] = useState({
    name: "",
    mobile: "",
  });

  const [searchResults, setSearchResults] = useState([]);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setSearchParams((prevState) => ({
      ...prevState,
      [name]: value,
    }));
  };

  const handleSearch = async (e) => {
    e.preventDefault();

    try {
      const queryParams = new URLSearchParams(searchParams).toString();
      const response = await fetch(`http://35.91.97.181:30088/api/search?${queryParams}`);
      const data = await response.json();
      setSearchResults(data);

      // Reset the form after a successful search
      setSearchParams({
        name: "",
        mobile: "",
      });
    } catch (error) {
      console.error("Error:", error);
      alert("Error fetching search results.");
    }
  };

  return (
    <div style={{ margin: "20px auto", maxWidth: "900px" }}>
      <h2 style={{ textAlign: "center" }}>Search Users</h2>
      <form onSubmit={handleSearch} autoComplete="off" style={{ marginBottom: "20px" }}>
        <div>
          <label>Name: </label>
          <input
            type="text"
            name="name"
            value={searchParams.name}
            onChange={handleChange}
            style={{ width: "100%", padding: "10px", marginBottom: "10px" }}
            autoComplete="off"
          />
        </div>
        <div>
          <label>Mobile: </label>
          <input
            type="text"
            name="mobile"
            value={searchParams.mobile}
            onChange={handleChange}
            style={{ width: "100%", padding: "10px", marginBottom: "10px" }}
            autoComplete="off"
          />
        </div>
        <button
          type="submit"
          style={{
            padding: "10px",
            backgroundColor: "#4CAF50",
            color: "white",
            width: "100%",
          }}
        >
          Search
        </button>
      </form>

      <div style={{ marginTop: "20px" }}>
        {searchResults.length > 0 ? (
          <table
            style={{
              width: "100%",
              borderCollapse: "collapse",
              marginTop: "20px",
              border: "1px solid #ddd",
            }}
          >
            <thead>
              <tr>
                <th style={tableHeaderStyle}>Name</th>
                <th style={tableHeaderStyle}>Age</th>
                <th style={tableHeaderStyle}>Mobile</th>
                <th style={tableHeaderStyle}>Place</th>
                <th style={tableHeaderStyle}>Amount</th>
              </tr>
            </thead>
            <tbody>
              {searchResults.map((user) => (
                <tr key={user.id} style={tableRowStyle}>
                  <td style={tableCellStyle}>{user.name}</td>
                  <td style={tableCellStyle}>{user.age}</td>
                  <td style={tableCellStyle}>{user.mobile}</td>
                  <td style={tableCellStyle}>{user.place}</td>
                  <td style={tableCellStyle}>${user.amount}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <p>No users found.</p>
        )}
      </div>
    </div>
  );
};

// Table styles
const tableHeaderStyle = {
  padding: "10px",
  backgroundColor: "#4CAF50",
  color: "white",
  textAlign: "left",
  fontWeight: "bold",
};

const tableRowStyle = {
  borderBottom: "1px solid #ddd",
};

const tableCellStyle = {
  padding: "10px",
  borderBottom: "1px solid #ddd",
};

export default SearchPage;
