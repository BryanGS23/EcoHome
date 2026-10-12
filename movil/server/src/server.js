const { WebSocketServer, WebSocket } = require('ws');
const { createInitialState, updateDeviceStatus, updateSceneStatus, addAlert } = require('./home_state');

function createEcoHomeServer({ port = 8080, logger = console } = {}) {
  const state = createInitialState();
  const server = new WebSocketServer({ port });

  const broadcast = (message) => {
    const serialized = JSON.stringify(message);
    for (const client of server.clients) {
      if (client.readyState === WebSocket.OPEN) client.send(serialized);
    }
  };
  const sendError = (socket, message) => {
    socket.send(JSON.stringify({ type: 'error', payload: { message } }));
  };

  server.on('connection', (socket, request) => {
    logger.info?.(`Cliente conectado: ${request.socket.remoteAddress}`);
    socket.send(JSON.stringify({ type: 'state_sync', payload: state }));
    socket.on('message', (rawMessage) => {
      let message;
      try { message = JSON.parse(rawMessage.toString()); } catch (_) {
        sendError(socket, 'JSON inválido.');
        return;
      }
      if (!message || typeof message.type !== 'string' || !message.payload) {
        sendError(socket, 'Mensaje WebSocket inválido.');
        return;
      }
      if (message.type === 'device_status') {
        const device = updateDeviceStatus(state, message.payload);
        if (!device) return sendError(socket, 'Dispositivo o estado inválido.');
        broadcast({ type: 'device_status', payload: device });
      } else if (message.type === 'scene_status') {
        const scene = updateSceneStatus(state, message.payload);
        if (!scene) return sendError(socket, 'Escena o estado inválido.');
        broadcast({ type: 'scene_status', payload: scene });
      } else if (message.type === 'alert') {
        const alert = addAlert(state, message.payload);
        if (!alert) return sendError(socket, 'Alerta inválida.');
        broadcast({ type: 'alert', payload: alert });
      } else {
        sendError(socket, `Tipo de mensaje no soportado: ${message.type}`);
      }
    });
    socket.on('close', () => logger.info?.('Cliente desconectado.'));
    socket.on('error', (error) => logger.error?.('Error de WebSocket:', error.message));
  });
  return { server, state };
}

module.exports = { createEcoHomeServer };
