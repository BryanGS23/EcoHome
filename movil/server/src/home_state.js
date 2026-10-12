function timestamp() {
  return new Date().toISOString();
}

function createInitialState() {
  const updatedAt = timestamp();
  return {
    devices: [
      { id: 'light_sala_1', name: 'Luz Sala', type: 'light', area: 'Sala', status: true, temperature: 22, updatedAt },
      { id: 'light_sala_2', name: 'Luz Sala auxiliar', type: 'light', area: 'Sala', status: true, temperature: 22, updatedAt },
      { id: 'light_cocina', name: 'Luz Cocina', type: 'light', area: 'Cocina', status: true, temperature: 24, updatedAt },
      { id: 'light_recamara_1', name: 'Luz Recámara', type: 'light', area: 'Recámara', status: true, temperature: 20, updatedAt },
      { id: 'light_recamara_2', name: 'Luz Recámara auxiliar', type: 'light', area: 'Recámara', status: true, temperature: 20, updatedAt },
      { id: 'light_bano', name: 'Luz Baño', type: 'light', area: 'Baño', status: false, temperature: 23, updatedAt },
      { id: 'camera_patio', name: 'Cámara Patio', type: 'camera', area: 'Patio', status: true, temperature: null, updatedAt },
    ],
    scenes: [
      { id: 'modo_noche', name: 'Modo Noche', active: false, updatedAt },
      { id: 'modo_casa', name: 'Modo Casa', active: true, updatedAt },
      { id: 'modo_away', name: 'Modo Away', active: false, updatedAt },
      { id: 'ahorro_energia', name: 'Ahorro de Energía', active: false, updatedAt },
    ],
    alerts: [],
    home: {
      currentTemperature: 22,
      comfortStatus: 'Confortable',
      securityActive: true,
      weeklyEnergyKwh: 345,
      activeCameras: 3,
    },
  };
}

function updateDeviceStatus(state, { id, status }) {
  const device = state.devices.find((item) => item.id === id);
  if (!device || typeof status !== 'boolean') return null;
  device.status = status;
  device.updatedAt = timestamp();
  return device;
}

function updateSceneStatus(state, { id, active }) {
  const scene = state.scenes.find((item) => item.id === id);
  if (!scene || typeof active !== 'boolean') return null;
  scene.active = active;
  scene.updatedAt = timestamp();
  return scene;
}

function addAlert(state, alert) {
  if (!alert || typeof alert.id !== 'string' || typeof alert.title !== 'string') return null;
  const normalized = {
    id: alert.id,
    title: alert.title,
    message: typeof alert.message === 'string' ? alert.message : '',
    type: typeof alert.type === 'string' ? alert.type : 'general',
    createdAt: alert.createdAt || timestamp(),
    read: Boolean(alert.read),
  };
  state.alerts.push(normalized);
  return normalized;
}

module.exports = { createInitialState, updateDeviceStatus, updateSceneStatus, addAlert };
