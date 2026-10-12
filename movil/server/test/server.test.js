const assert = require('node:assert/strict');
const test = require('node:test');
const WebSocket = require('ws');
const { createEcoHomeServer } = require('../src/server');

function nextMessage(socket, expectedType) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error(`No llegó ${expectedType}`)), 1500);
    const onMessage = (raw) => {
      const message = JSON.parse(raw.toString());
      if (message.type !== expectedType) return;
      clearTimeout(timeout);
      socket.off('message', onMessage);
      resolve(message);
    };
    socket.on('message', onMessage);
  });
}

async function openClient(url) {
  let resolveOpen;
  let rejectOpen;
  const opened = new Promise((resolve, reject) => {
    resolveOpen = resolve;
    rejectOpen = reject;
  });
  const socket = new WebSocket(url);
  const stateSync = nextMessage(socket, 'state_sync');
  socket.once('open', resolveOpen);
  socket.once('error', rejectOpen);
  await opened;
  return { socket, stateSync };
}

test('sincroniza estado, dispositivo, escena y alerta entre clientes', async (t) => {
  const { server } = createEcoHomeServer({ port: 0, logger: { info() {}, error() {} } });
  let first;
  let second;
  t.after(async () => {
    first?.terminate();
    second?.terminate();
    await new Promise((resolve) => server.close(resolve));
  });
  await new Promise((resolve) => server.once('listening', resolve));
  const { port } = server.address();
  const url = `ws://127.0.0.1:${port}`;
  ({ socket: first, stateSync: firstSync } = await openClient(url));
  const sync = await firstSync;
  assert.ok(sync.payload.devices.length > 0);
  ({ socket: second, stateSync: secondSync } = await openClient(url));
  await secondSync;

  const deviceUpdate = nextMessage(second, 'device_status');
  first.send(JSON.stringify({ type: 'device_status', payload: { id: 'light_sala_1', status: true } }));
  assert.equal((await deviceUpdate).payload.status, true);
  const sceneUpdate = nextMessage(first, 'scene_status');
  second.send(JSON.stringify({ type: 'scene_status', payload: { id: 'modo_noche', active: true } }));
  assert.equal((await sceneUpdate).payload.active, true);
  const alertUpdate = nextMessage(second, 'alert');
  first.send(JSON.stringify({ type: 'alert', payload: { id: 'alert_001', title: 'Puerta principal abierta', message: 'La puerta principal fue abierta', type: 'security', createdAt: '2026-08-10T20:00:00Z' } }));
  assert.equal((await alertUpdate).payload.title, 'Puerta principal abierta');
});
