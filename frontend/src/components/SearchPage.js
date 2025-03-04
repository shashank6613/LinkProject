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
      const response = await fetch(`http://backend:5000/api/search?${queryParams}`);
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
    <div style={{ margin: "20px auto", maxWidth: "600px" }}>
      <h2 style={{ textAlign: "center" }}>Search Users</h2>
      <form onSubmit={handleSearch} autocomplete="off">
        <div>
          <label>Name: </label>
          <input
            type="text"
            name="name"
            value={searchParams.name}
            onChange={handleChange}
            style={{ width: "100%", padding: "10px", marginBottom: "10px" }}
            autocomplete="off"
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
            autocomplete="off"
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
        <h3>Search Results</h3>
        <ul>
          {searchResults.map((user) => (
            <li key={user.id}>
              {user.name}, {user.mobile}, {user.place}, ${user.amount}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
};

export default SearchPage;
