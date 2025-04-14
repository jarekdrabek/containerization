import React, { useEffect, useState } from 'react';
import axios from 'axios';

function App() {
  const [users, setUsers] = useState([]);
  const [items, setItems] = useState([]);

  useEffect(() => {
    axios.get('/users')
      .then(response => setUsers(response.data))
      .catch(err => console.error('User API error:', err));

    axios.get('/items')
      .then(response => setItems(response.data))
      .catch(err => console.error('Item API error:', err));
  }, []);

  return (
    <div style={{ margin: '20px' }}>
      <h1>Frontend Service</h1>
      <h2>Users</h2>
      <ul>
        {users.map(u => <li key={u.id}>{u.name}</li>)}
      </ul>
      <h2>Items</h2>
      <ul>
        {items.map(i => <li key={i.id}>{i.name} - ${i.price}</li>)}
      </ul>
    </div>
  );
}

export default App;
