import React, { useState } from "react";

const UserForm = () => {
  const [userData, setUserData] = useState({
    name: "",
    age: "",
    mobile: "",
    place: "",
    amount: "",
  });

  // Handle form input changes
  const handleChange = (e) => {
    const { name, value } = e.target;
    setUserData((prevState) => ({
      ...prevState,
      [name]: value,
    }));
  };

  // Handle form submission
  const handleSubmit = async (e) => {
    e.preventDefault();

    // Simple validation for required fields
    if (!userData.name || !userData.age || !userData.mobile || !userData.place || !userData.amount) {
      alert("Please fill all fields");
      return;
    }

    try {
      const response = await fetch("http://backend-service:5000/api/data", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(userData),
      });

      const data = await response.json();
      if (data.success) {
        alert("User added successfully!");

        // Reset form after successful submission
        setUserData({
          name: "",
          age: "",
          mobile: "",
          place: "",
          amount: "",
        });
      } else {
        alert("Failed to add user.");
      }
    } catch (error) {
      console.error("Error:", error);
      alert("Error submitting form.");
    }
  };

  const formStyle = {
    maxWidth: "500px",
    margin: "50px auto",
    padding: "20px",
    borderRadius: "8px",
    backgroundColor: "#f7f7f7",
    boxShadow: "0 4px 8px rgba(0,0,0,0.1)",
  };

  const labelStyle = {
    display: "block",
    marginBottom: "8px",
    fontSize: "14px",
    fontWeight: "bold",
    color: "#333",
  };

  const inputStyle = {
    width: "100%",
    padding: "12px",
    marginBottom: "15px",
    fontSize: "14px",
    borderRadius: "5px",
    border: "1px solid #ddd",
  };

  const buttonStyle = {
    width: "100%",
    padding: "12px",
    backgroundColor: "#4CAF50",
    color: "white",
    border: "none",
    fontSize: "16px",
    borderRadius: "5px",
    cursor: "pointer",
    transition: "background-color 0.3s ease",
  };

  const buttonHoverStyle = {
    backgroundColor: "#45a049",
  };

  return (
    <div style={formStyle}>
      <h2 style={{ textAlign: "center", color: "#333" }}>Enter User Information</h2>
      <form onSubmit={handleSubmit} autoComplete="off">
        <div>
          <label style={labelStyle}>Name: </label>
          <input
            type="text"
            name="name"
            value={userData.name}
            onChange={handleChange}
            style={inputStyle}
            required
            autoComplete="off"
          />
        </div>
        <div>
          <label style={labelStyle}>Age: </label>
          <input
            type="number"
            name="age"
            value={userData.age}
            onChange={handleChange}
            style={inputStyle}
            required
            autoComplete="off"
          />
        </div>
        <div>
          <label style={labelStyle}>Mobile: </label>
          <input
            type="text"
            name="mobile"
            value={userData.mobile}
            onChange={handleChange}
            style={inputStyle}
            required
            autoComplete="off"
          />
        </div>
        <div>
          <label style={labelStyle}>Place: </label>
          <input
            type="text"
            name="place"
            value={userData.place}
            onChange={handleChange}
            style={inputStyle}
            required
            autoComplete="off"
          />
        </div>
        <div>
          <label style={labelStyle}>Amount: </label>
          <input
            type="number"
            name="amount"
            value={userData.amount}
            onChange={handleChange}
            style={inputStyle}
            required
            autoComplete="off"
          />
        </div>
        <button
          type="submit"
          style={buttonStyle}
          onMouseEnter={(e) => (e.target.style.backgroundColor = buttonHoverStyle.backgroundColor)}
          onMouseLeave={(e) => (e.target.style.backgroundColor = "#4CAF50")}
        >
          Submit
        </button>
      </form>
    </div>
  );
};

export default UserForm;
