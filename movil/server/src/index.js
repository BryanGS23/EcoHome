const { createEcoHomeServer } = require('./server');

const { server } = createEcoHomeServer({ port: 8080 });
server.on('listening', () => console.log('Servidor WebSocket EcoHome en ws://0.0.0.0:8080'));
