require('dotenv').config();
const http = require('http');
const app = require('./app');
const connectDB = require('./config/db');
const initSockets = require('./sockets');

const PORT = process.env.PORT || 5000;

async function start() {
  await connectDB();
  const server = http.createServer(app);
  initSockets(server);
  server.listen(PORT, () => {
    console.log(`[server] Prosim Planat API listening on port ${PORT}`);
  });
}

start();
