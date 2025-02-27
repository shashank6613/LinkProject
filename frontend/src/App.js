import React from "react";
import { BrowserRouter as Router, Route, Switch, Link } from "react-router-dom";
import UserForm from "./components/UserForm";
import SearchPage from "./components/SearchPage";

const App = () => {
  return (
    <Router>
      <div style={{ textAlign: "center", padding: "20px" }}>
        <h1>Full-Stack Application</h1>
        <div>
          <Link to="/" style={{ padding: "10px", backgroundColor: "#4CAF50", color: "white", margin: "10px" }}>Go to Form</Link>
          <Link to="/search" style={{ padding: "10px", backgroundColor: "#4CAF50", color: "white", margin: "10px" }}>Go to Search</Link>
        </div>

        <Switch>
          <Route exact path="/" component={UserForm} />
          <Route path="/search" component={SearchPage} />
        </Switch>
      </div>
    </Router>
  );
};

export default App;
