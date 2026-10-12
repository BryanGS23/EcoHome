const { test } = require('node:test');
const assert = require('node:assert/strict');
const {seedHome, seedScenes, seedPowers, scenes, fields} = require('../scripts/seed_home.cjs');
const project = 'demo-ecohome-rules';
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (host !== '127.0.0.1:8085') throw new Error('Solo ejecutar contra Firestore local 127.0.0.1:8085.');
const database = `projects/${project}/databases/(default)`;
const base = `http://${host}/v1/${database}/documents`;
function token(uid) {
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({ alg: 'none', typ: 'JWT' })}.${encode({
    sub: uid, user_id: uid, email: `${uid}@example.test`,
    aud: project, iss: `https://securetoken.google.com/${project}`,
    iat: Math.floor(Date.now()/1000), exp: Math.floor(Date.now()/1000)+3600,
    firebase: { sign_in_provider: 'password' }
  })}.`;
}
async function request(path, uid, body) {
  const headers = { 'Content-Type': 'application/json' };
  if (uid) headers.Authorization = `Bearer ${uid === 'owner' ? 'owner' : token(uid)}`;
  const response = await fetch(base + path, { signal: AbortSignal.timeout(15000), method: body ? 'POST' : 'GET', headers,
    body: body ? JSON.stringify(body) : undefined });
  return { status: response.status, body: await response.json() };
}
async function create(uid, changes = {}, caller = uid) {
  return request(':commit', caller, {writes:[{
    update:{ name:`${database}/documents/users/${uid}`, fields:fields({
      uid, name:'Persona', email:`${uid}@example.test`, role:'user', active:true, ...changes
    })},
    currentDocument:{exists:false},
    updateTransforms:['createdAt','updatedAt'].map(fieldPath => ({fieldPath,setToServerValue:'REQUEST_TIME'}))
  }]});
}
async function update(uid, changes, caller = uid) {
  return request(':commit', caller, {writes:[{
    update:{name:`${database}/documents/users/${uid}`,fields:fields(changes)},
    updateMask:{fieldPaths:Object.keys(changes)},
    currentDocument:{exists:true},
    updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]
  }]});
}
const allowed = result => assert.equal(result.status, 200, JSON.stringify(result.body));
const denied = result => assert.equal(result.status, 403, JSON.stringify(result.body));

// All fixtures and administrative writes in these tests stay in the demo emulator.
const writeDoc = (collection,id,data,{create=false}={}) => ({
  update:{name:`${database}/documents/${collection}/${id}`,fields:fields(data)},
  ...(create?{currentDocument:{exists:false}}:{updateMask:{fieldPaths:Object.keys(data)}}),
  updateTransforms:(create?['createdAt','updatedAt']:['updatedAt']).map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))
});
async function adminCommit(writes,uid='admin') {
  const lock=await request('/_admin/catalog','owner');
  const revision=Number(lock.body.fields?.revision?.integerValue ?? lock.body.fields?.revision?.doubleValue ?? 0)+1;
  return request(':commit',uid,{writes:[...writes,{
    update:{name:`${database}/documents/_admin/catalog`,fields:{revision:{integerValue:String(revision)}}},
    updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]
  }]});
}
const adminEvent=(id,action,type,entityId,changes={})=>({
  update:{name:`${database}/documents/activity/${id}`,fields:fields({userId:'admin',action,entityType:type,entityId,description:'Operación administrativa',...changes})},
  currentDocument:{exists:false},
  updateTransforms:[{fieldPath:'createdAt',setToServerValue:'REQUEST_TIME'}]
});

test('reglas mínimas de perfiles: permisos reales del motor Firestore', async t => {
  await t.test('cuenta antigua puede consultar su documento inexistente', async () => {
    const result = await request('/users/legacy','legacy');
    assert.equal(result.status,404,JSON.stringify(result.body));
    allowed(await create('legacy'));
  });
  await t.test('creación propia user activo', async () => allowed(await create('alice')));
  await t.test('lectura propia', async () => allowed(await request('/users/alice','alice')));
  await t.test('sin autenticación no lee ni crea', async () => {
    denied(await request('/users/alice',null)); denied(await create('anonymous',{},null));
  });
  await t.test('no lee otro perfil ni lista usuarios', async () => {
    denied(await request('/users/alice','bob')); denied(await request('/users','alice'));
  });
  await t.test('no crea perfil ajeno', async () => denied(await create('victim',{},'alice')));
  await t.test('no crea admin o inactivo ni falsifica UID/correo', async () => {
    for(const changes of [{role:'admin'},{active:false},{uid:'other'},{email:'other@example.test'}])
      denied(await create('malicious',changes));
  });
  await t.test('no guarda tokens ni campos extra', async () => denied(await create('extra',{token:'secret'})));
  await t.test('edita nombre propio', async () => allowed(await update('alice',{name:'Ana'})));
  await t.test('no cambia rol estado UID correo ni agrega campos', async () => {
    for(const change of [{role:'admin'},{active:false},{uid:'other'},{email:'other@example.test'},{token:'x'}])
      denied(await update('alice',change));
  });
  await t.test('no cambia createdAt ni omite timestamp del servidor', async () => {
    denied(await request(':commit','alice',{writes:[{
      update:{name:`${database}/documents/users/alice`,fields:{createdAt:{timestampValue:'2000-01-01T00:00:00Z'}}},
      updateMask:{fieldPaths:['createdAt']},
      updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]
    }]}));
    denied(await request(':commit','alice',{writes:[{
      update:{name:`${database}/documents/users/alice`,fields:fields({name:'Otro'})},
      updateMask:{fieldPaths:['name']}
    }]}));
  });
  await t.test('no elimina campos protegidos ni guarda nombres inválidos', async () => {
    denied(await request(':commit','alice',{writes:[{
      update:{name:`${database}/documents/users/alice`,fields:{}},
      updateMask:{fieldPaths:['email']},
      updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]
    }]}));
    denied(await update('alice',{name:''}));
    denied(await update('alice',{name:' '.repeat(5)}));
    denied(await update('alice',{name:'x'.repeat(81)}));
  });
  await t.test('no edita otro usuario', async () => denied(await update('alice',{name:'Otro'},'bob')));
  await t.test('no borra su documento', async () => denied(await request(':commit','alice',{
    writes:[{delete:`${database}/documents/users/alice`}]
  })));
  await t.test('inactivo puede leer pero no editar/reactivarse', async () => {
    allowed(await update('alice',{active:false},'owner'));
    allowed(await request('/users/alice','alice'));
    denied(await update('alice',{name:'Otro'}));
    denied(await update('alice',{active:true}));
  });
  await t.test('admin no puede quitarse su propio rol', async () => {
    allowed(await create('admin',{role:'admin'},'owner'));
    allowed(await request('/users/admin','admin'));
    allowed(await update('admin',{name:'Administrador'}));
    denied(await update('admin',{role:'user'}));
    allowed(await request('/users/alice','admin'));
  });
  await t.test('otras colecciones siguen cerradas', async () => denied(await request('/private_legacy/example','admin')));
});

test('núcleo del hogar: seed y permisos de áreas/dispositivos', async t => {
  const seedClient={post:async(url,body)=>{
    const response=await fetch(`http://${host}/v1${url}`,{method:'POST',
      headers:{'Content-Type':'application/json',Authorization:'Bearer owner'},body:JSON.stringify(body)});
    const data=await response.json();
    assert.equal(response.status,200,JSON.stringify(data));
    return data;
  }};
  const control=async(id,changes,uid='controller')=>request(':commit',uid,{writes:[{
    update:{name:`${database}/documents/devices/${id}`,fields:fields(changes)},
    updateMask:{fieldPaths:Object.keys(changes)},
    updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]
  }]});
  await t.test('seed explícito atómico: preview, creación e idempotencia sin sobrescribir',async()=>{
    assert.equal((await seedHome(seedClient,project)).status,'preview');
    assert.equal((await seedHome(seedClient,project,true)).status,'created');
    allowed(await control('light_sala_1',{name:'Nombre conservado',enabled:false},'owner'));
    const before=await request('/devices/light_sala_1','owner');
    assert.equal((await seedHome(seedClient,project,true)).status,'skipped');
    const after=await request('/devices/light_sala_1','owner');
    assert.deepEqual(after.body,before.body);
  });
  await t.test('activo lee áreas y dispositivos; anónimo/sin perfil/inactivo no',async()=>{
    allowed(await create('controller'));
    allowed(await create('disabled'));
    allowed(await update('disabled',{active:false},'owner'));
    for(const collection of ['areas','devices']) {
      allowed(await request(`/${collection}`,'controller'));
      for(const uid of [null,'no-profile','disabled']) denied(await request(`/${collection}`,uid));
    }
  });
  await t.test('controles válidos por tipo; valores fuera de rango y sensores rechazados',async()=>{
    for(const [id,value] of [['light_sala_1',50],['fan_sala',3],['ac_recamara',26]]) {
      allowed(await control(id,{enabled:true,value}));
    }
    for(const id of ['camera_patio','lock_patio']) allowed(await control(id,{enabled:false}));
    for(const [id,value] of [['light_sala_1',101],['fan_sala',0],['fan_sala',1.5],['ac_recamara',31],['lock_patio',1]]) {
      denied(await control(id,{value}));
    }
    denied(await control('sensor_patio',{enabled:false}));
    denied(await control('sensor_patio',{value:25}));
  });
  await t.test('protege campos administrativos y timestamps, incluso combinados con controles',async()=>{
    for(const changes of [{name:'Renombrar'},{type:'outlet'},{areaId:'patio'},{online:false},{energyConsumption:100},{extra:'x'}]) {
      denied(await control('light_sala_1',{enabled:true,...changes}));
    }
    denied(await request(':commit','controller',{writes:[{
      update:{name:`${database}/documents/devices/light_sala_1`,fields:{createdAt:{timestampValue:'2000-01-01T00:00:00Z'}}},
      updateMask:{fieldPaths:['createdAt']},updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]
    }]}));
    denied(await request(':commit','controller',{writes:[{
      update:{name:`${database}/documents/devices/light_sala_1`,fields:{enabled:{booleanValue:false},updatedAt:{timestampValue:'2000-01-01T00:00:00Z'}}},
      updateMask:{fieldPaths:['enabled','updatedAt']}
    }]}));
  });
  await t.test('CRUD incompleto o sin transacción de catálogo se rechaza',async()=>{
    for(const uid of ['controller','admin']) {
      for(const collection of ['areas','devices']) {
        denied(await request(':commit',uid,{writes:[{update:{name:`${database}/documents/${collection}/new`,fields:fields({name:'Nuevo'})}}]}));
        const id=collection==='areas'?'sala':'light_sala_1';
        denied(await request(':commit',uid,{writes:[{delete:`${database}/documents/${collection}/${id}`}]}));
      }
      denied(await request(':commit',uid,{writes:[{update:{name:`${database}/documents/areas/sala`,fields:fields({name:'Otro'})},updateMask:{fieldPaths:['name']}}]}));
    }
  });
  await t.test('inactivo y dispositivo offline no pueden controlar',async()=>{
    denied(await control('light_sala_1',{enabled:true},'disabled'));
    denied(await control('light_sala_1',{enabled:true},'no-profile'));
    denied(await control('light_sala_1',{enabled:true},null));
    allowed(await control('light_sala_1',{online:false},'owner'));
    denied(await control('light_sala_1',{enabled:true}));
    allowed(await control('light_sala_1',{online:true},'owner'));
    allowed(await update('controller',{active:false},'owner'));
    denied(await control('light_sala_1',{enabled:true}));
  });
});

test('escenas: seed, permisos y ejecución atómica',async t=>{
  const client={post:async(url,body)=>{
    const response=await fetch(`http://${host}/v1${url}`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer owner'},body:JSON.stringify(body)});
    const data=await response.json();assert.equal(response.status,200,JSON.stringify(data));return data;
  }};
  const control=async(id,changes)=>request(':commit','owner',{writes:[{
    update:{name:`${database}/documents/devices/${id}`,fields:fields(changes)},updateMask:{fieldPaths:Object.keys(changes)},
    updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]
  }]});
  await t.test('seed añade cuatro escenas sin modificar hogar y conserva escenas personalizadas',async()=>{
    const before=await request('/devices','owner');
    assert.equal((await seedScenes(client,project)).status,'preview');
    assert.equal((await seedScenes(client,project,true)).scenes,4);
    assert.deepEqual((await request('/devices','owner')).body,before.body);
    allowed(await request(':commit','owner',{writes:[{update:{name:`${database}/documents/scenes/modo_noche`,fields:fields({name:'Mi noche'})},updateMask:{fieldPaths:['name']}}]}));
    const customized=await request('/scenes/modo_noche','owner');
    assert.equal((await seedScenes(client,project,true)).status,'skipped');
    assert.deepEqual((await request('/scenes/modo_noche','owner')).body,customized.body);
  });
  await t.test('solo activos leen escenas, clientes no crean ni editan ni borran',async()=>{
    allowed(await create('scene-user'));
    allowed(await request('/scenes','scene-user'));
    for(const uid of [null,'no-profile','disabled'])denied(await request('/scenes',uid));
    for(const uid of ['scene-user','admin']) {
      for(const change of [{name:'Otro'},{enabled:false},{actions:[]}]) {
        denied(await request(':commit',uid,{writes:[{update:{name:`${database}/documents/scenes/modo_noche`,fields:fields(change)},updateMask:{fieldPaths:Object.keys(change)}}]}));
      }
      denied(await request(':commit',uid,{writes:[{delete:`${database}/documents/scenes/modo_noche`}]}));
      denied(await request(':commit',uid,{writes:[{update:{name:`${database}/documents/scenes/new`,fields:fields({name:'Nueva'})}}]}));
    }
  });
  await t.test('transacción aplica múltiples controles con reglas existentes sin cambiar escena',async()=>{
    const original=await request('/scenes/modo_away','scene-user');
    const transaction=(await request(':beginTransaction','scene-user',{})).body.transaction;
    allowed(await request(':batchGet','scene-user',{transaction,documents:[`${database}/documents/scenes/modo_away`]}));
    const actions=scenes.find(scene=>scene.id==='modo_away').actions;
    const reads=await request(':batchGet','scene-user',{transaction,documents:actions.map(a=>`${database}/documents/devices/${a.deviceId}`)});
    allowed(reads);
    allowed(await request(':commit','scene-user',{transaction,writes:actions.map(action=>({
      update:{name:`${database}/documents/devices/${action.deviceId}`,fields:fields({enabled:action.enabled})},
      updateMask:{fieldPaths:['enabled']},updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]
    }))}));
    for(const action of actions)assert.equal((await request(`/devices/${action.deviceId}`,'scene-user')).body.fields.enabled.booleanValue,action.enabled);
    assert.deepEqual((await request('/scenes/modo_away','scene-user')).body,original.body);
  });
  await t.test('commit rechazado por un dispositivo offline no cambia ningún otro',async()=>{
    allowed(await control('camera_patio',{online:false}));
    const before=await request('/devices/light_sala_1','scene-user');
    denied(await request(':commit','scene-user',{writes:['light_sala_1','camera_patio'].map(id=>({
      update:{name:`${database}/documents/devices/${id}`,fields:fields({enabled:true})},updateMask:{fieldPaths:['enabled']},
      updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]
    }))}));
    assert.deepEqual((await request('/devices/light_sala_1','scene-user')).body,before.body);
    allowed(await control('camera_patio',{online:true}));
  });
  await t.test('seed aborta sin escrituras si falta un dispositivo de una escena pendiente',async()=>{
    allowed(await request(':commit','owner',{writes:[{delete:`${database}/documents/scenes/modo_casa`},{delete:`${database}/documents/devices/light_cocina`}]}));
    await assert.rejects(seedScenes(client,project,true),/Falta dispositivo demo/);
    assert.equal((await request('/scenes/modo_casa','owner')).status,404);
    assert.equal((await request('/scenes/modo_noche','owner')).body.fields.name.stringValue,'Mi noche');
  });
});

test('energía y actividad: permisos, deduplicación y atomicidad',async t=>{
  const client={post:async(url,body)=>{
    const response=await fetch(`http://${host}/v1${url}`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer owner'},body:JSON.stringify(body)});
    const data=await response.json();assert.equal(response.status,200,JSON.stringify(data));return data;
  }};
  const writeDevice=(changes)=>({update:{name:`${database}/documents/devices/light_sala_1`,fields:fields(changes)},
    updateMask:{fieldPaths:Object.keys(changes)},updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]});
  const event=(id,changes={})=>({update:{name:`${database}/documents/activity/${id}`,fields:fields({
    userId:'energy-user',action:'device_control',entityType:'device',entityId:'light_sala_1',description:'Cambió Luz Sala',...changes})},
    updateTransforms:[{fieldPath:'createdAt',setToServerValue:'REQUEST_TIME'}]});
  const day=Math.floor(Date.now()/86400000),recordId=`light_sala_1_${day}`;
  const sample=(changes={},id=recordId)=>({update:{name:`${database}/documents/energy_records/${id}`,fields:fields({
    deviceId:'light_sala_1',areaId:'sala',powerWatts:90,durationHours:1,consumption:90,...changes})},
    updateTransforms:[{fieldPath:'recordedAt',setToServerValue:'REQUEST_TIME'}]});
  await t.test('seed de potencias completa solo ceros y conserva personalizaciones',async()=>{
    allowed(await request(':commit','owner',{writes:[writeDevice({energyConsumption:0})]}));
    const before=(await request('/devices/light_sala_2','owner')).body;
    assert.equal((await seedPowers(client,project)).status,'preview');
    assert.equal((await seedPowers(client,project,true)).status,'updated');
    assert.equal((await seedPowers(client,project,true)).status,'skipped');
    assert.deepEqual((await request('/devices/light_sala_2','owner')).body,before);
  });
  await t.test('control y evento se confirman juntos; atribución ajena aborta ambos',async()=>{
    allowed(await create('energy-user'));
    allowed(await request(':commit','owner',{writes:[writeDevice({online:true,enabled:true,energyConsumption:90})]}));
    allowed(await request(':commit','energy-user',{writes:[writeDevice({enabled:false}),event('control-ok')]}));
    const before=(await request('/devices/light_sala_1','energy-user')).body;
    denied(await request(':commit','energy-user',{writes:[writeDevice({enabled:true}),event('forged',{userId:'admin'})]}));
    assert.deepEqual((await request('/devices/light_sala_1','energy-user')).body,before);
    assert.equal((await request('/activity/forged','owner')).status,404);
    // Legitimate scene event, one per scene, uses the same device-control permissions.
    allowed(await request(':commit','energy-user',{writes:[writeDevice({enabled:true}),event('scene-ok',{
      action:'scene_executed',entityType:'scene',entityId:'modo_noche',description:'Ejecutó escena Modo Noche'})]}));
  });
  await t.test('actividad privada e inmutable, consultas propias limitadas',async()=>{
    allowed(await request('/activity/control-ok','energy-user'));
    allowed(await request('/activity/control-ok','admin'));
    denied(await request('/activity/control-ok',null));
    const query={structuredQuery:{from:[{collectionId:'activity'}],where:{fieldFilter:{field:{fieldPath:'userId'},op:'EQUAL',value:{stringValue:'energy-user'}}},orderBy:[{field:{fieldPath:'createdAt'},direction:'DESCENDING'}],limit:50}};
    allowed(await request(':runQuery','energy-user',query));
    allowed(await request(':runQuery','admin',query));
    denied(await request('/activity?pageSize=50','energy-user'));
    denied(await request(':commit','energy-user',{writes:[event('control-ok')]}));
    denied(await request(':commit','energy-user',{writes:[{delete:`${database}/documents/activity/control-ok`}]}));
    denied(await request(':commit','energy-user',{writes:[event('no-operation')]}));
    denied(await request(':commit','energy-user',{writes:[writeDevice({enabled:true}),event('extra',{token:'secret'})]}));
  });
  await t.test('energía valida potencia, cálculo, área, fecha canónica y esquema antes de crear',async()=>{
    for(const changes of [{powerWatts:91,consumption:91},{consumption:80},{durationHours:2,consumption:180},{areaId:'patio'},{token:'x'}]){
      denied(await request(':commit','energy-user',{writes:[sample(changes)]}));
    }
    denied(await request(':commit','energy-user',{writes:[sample({},'random-id')]}));
    allowed(await request(':commit','energy-user',{writes:[sample()]}));
    allowed(await request(`/energy_records/${recordId}`,'admin'));
    denied(await request(`/energy_records/${recordId}`,null));
    denied(await request(':commit','energy-user',{writes:[sample()]}));
    denied(await request(':commit','energy-user',{writes:[{delete:`${database}/documents/energy_records/${recordId}`}]}));
  });
  await t.test('inactivo no lee energía/actividad ni crea eventos',async()=>{
    allowed(await update('energy-user',{active:false},'owner'));
    denied(await request(`/energy_records/${recordId}`,'energy-user'));
    denied(await request('/activity/control-ok','energy-user'));
    denied(await request(':commit','energy-user',{writes:[event('inactive',{action:'scene_executed',entityType:'scene',entityId:'modo_noche'})]}));
  });
});

test('administración: privilegios mínimos, CRUD y revocación',async t=>{
  const area={name:'Área administrativa'};
  const device={name:'Lámpara administrativa',type:'light',areaId:'admin-area',enabled:true,online:true,value:50,energyConsumption:9};
  const scene={name:'Escena administrativa',enabled:true,actions:[{deviceId:'admin-device',enabled:false,value:20}]};
  await t.test('admin lista perfiles; user no puede autopromoverse ni alterar identidad',async()=>{
    allowed(await create('admin-target'));
    allowed(await request('/users','admin'));
    denied(await request('/users','admin-target'));
    denied(await update('admin-target',{role:'admin'}));
    for(const change of [{uid:'x'},{email:'x@test.com'},{name:'Ajeno'},{createdAt:'x'},{role:'owner'},{token:'x'}])denied(await update('admin-target',change,'admin'));
    denied(await request(':commit','admin',{writes:[{delete:`${database}/documents/users/admin-target`}]}));
  });
  await t.test('admin cambia rol y active ajenos pero nunca propios',async()=>{
    allowed(await adminCommit([writeDoc('users','admin-target',{role:'admin',active:false}),adminEvent('admin-profile','admin_update','users','admin-target')]));
    denied(await request('/users','admin-target'));
    allowed(await update('admin-target',{role:'user',active:true},'admin'));
    denied(await update('admin',{role:'user'}));
    denied(await update('admin',{active:false}));
  });
  await t.test('área CRUD y actividad son atómicos; user no puede escribir catálogo',async()=>{
    denied(await adminCommit([writeDoc('areas','admin-area',area,{create:true})],'admin-target'));
    denied(await request('/_admin/catalog','admin-target'));
    allowed(await adminCommit([writeDoc('areas','admin-area',area,{create:true}),adminEvent('admin-area-create','admin_create','areas','admin-area')]));
    allowed(await adminCommit([writeDoc('areas','admin-area',{name:'Área renombrada'}),adminEvent('admin-area-update','admin_update','areas','admin-area')]));
    for(const changes of [{name:''},{name:' '.repeat(4)},{extra:true},{createdAt:'x'}])denied(await adminCommit([writeDoc('areas','admin-area',changes)]));
    denied(await adminCommit([writeDoc('areas','admin-area',{name:'No guardar'}),adminEvent('admin-bad-uid','admin_update','areas','admin-area',{userId:'other'})]));
    assert.equal((await request('/areas/admin-area','admin')).body.fields.name.stringValue,'Área renombrada');
    assert.equal((await request('/activity/admin-bad-uid','owner')).status,404);
  });
  await t.test('dispositivo CRUD valida área, tipo, rango, potencia y esquema',async()=>{
    for(const changes of [{areaId:'missing'},{type:'invalid'},{value:101},{energyConsumption:-1},{energyConsumption:100001},{online:'true'},{extra:1}]) {
      denied(await adminCommit([writeDoc('devices','bad-device',{...device,...changes},{create:true})]));
    }
    allowed(await adminCommit([writeDoc('devices','admin-device',device,{create:true}),adminEvent('admin-device-create','admin_create','devices','admin-device')]));
    allowed(await adminCommit([writeDoc('devices','admin-device',{name:'Luz editada',online:false,energyConsumption:12}),adminEvent('admin-device-update','admin_update','devices','admin-device')]));
    denied(await request(':commit','admin-target',{writes:[writeDoc('devices','admin-device',{name:'Prohibido'})]}));
    allowed(await adminCommit([writeDoc('devices','admin-device',{online:true})]));
    allowed(await request(':commit','admin-target',{writes:[writeDoc('devices','admin-device',{enabled:false,value:10})]}));
  });
  await t.test('escenas CRUD permite habilitar/deshabilitar y rechaza acciones malformadas',async()=>{
    for(const changes of [{actions:[]},{actions:Array(21).fill(scene.actions[0])},{actions:[{deviceId:'x',enabled:'true'}]},{actions:[{deviceId:'x',enabled:true,extra:1}]},{enabled:1}]) {
      denied(await adminCommit([writeDoc('scenes','bad-scene',{...scene,...changes},{create:true})]));
    }
    allowed(await adminCommit([writeDoc('scenes','admin-scene',scene,{create:true}),adminEvent('admin-scene-create','admin_create','scenes','admin-scene')]));
    allowed(await adminCommit([writeDoc('scenes','admin-scene',{enabled:false}),adminEvent('admin-scene-disable','admin_update','scenes','admin-scene')]));
    denied(await request(':commit','admin-target',{writes:[adminEvent('disabled-execution','scene_executed','scene','admin-scene',{userId:'admin-target'})]}));
    allowed(await adminCommit([writeDoc('scenes','admin-scene',{enabled:true})]));
    // Upper bound must remain usable within the rules evaluation budget.
    allowed(await adminCommit([writeDoc('scenes','admin-scene',{actions:Array.from({length:20},(_,i)=>({deviceId:'test-'+i,enabled:false,value:0}))}),adminEvent('admin-scene-20','admin_update','scenes','admin-scene')]));
  });
  await t.test('actividad global limitada a 100 solo admin, jamás edición ni borrado',async()=>{
    const query=limit=>({structuredQuery:{from:[{collectionId:'activity'}],orderBy:[{field:{fieldPath:'createdAt'},direction:'DESCENDING'}],limit}});
    allowed(await request(':runQuery','admin',query(100)));
    denied(await request(':runQuery','admin',query(101)));
    denied(await request(':runQuery','admin-target',query(50)));
    for(const uid of ['admin','admin-target']) {
      denied(await request(':commit',uid,{writes:[{delete:`${database}/documents/activity/admin-area-create`}]}));
      denied(await request(':commit',uid,{writes:[{update:{name:`${database}/documents/activity/admin-area-create`,fields:fields({description:'Falso'})},updateMask:{fieldPaths:['description']}}]}));
    }
    denied(await request(':commit','admin',{writes:[adminEvent('no-mutation','admin_update','areas','admin-area')]}));
  });
  await t.test('delete administrativo válido registra actividad sin cambiar energía ni alertas',async()=>{
    for(const [type,id] of [['scenes','admin-scene'],['devices','admin-device'],['areas','admin-area']]) {
      allowed(await adminCommit([{delete:`${database}/documents/${type}/${id}`},adminEvent(`delete-${type}`,'admin_delete',type,id)]));
      assert.equal((await request(`/${type}/${id}`,'admin')).status,404);
    }
    denied(await request(':commit','admin',{writes:[{update:{name:`${database}/documents/alerts/x`,fields:fields({message:'x'})}}]}));
    denied(await request(':commit','admin',{writes:[{delete:`${database}/documents/energy_records/any`}]}));
  });
  await t.test('revocar rol o active quita lectura global y escrituras administrativas inmediatamente',async()=>{
    allowed(await update('admin',{role:'user'},'owner'));
    denied(await request('/users','admin'));
    denied(await adminCommit([writeDoc('areas','revoked',{name:'No'},{create:true})]));
    allowed(await update('admin',{role:'admin',active:false},'owner'));
    denied(await request('/users','admin'));
    denied(await request('/activity/admin-area-create','admin'));
    denied(await adminCommit([writeDoc('areas','inactive',{name:'No'},{create:true})]));
    allowed(await update('admin',{active:true},'owner'));
    allowed(await request('/users','admin'));
  });
});

test('alertas propias: creación simulada restringida y lectura segura',async t=>{
  const day=Math.floor(Date.now()/86400000);
  const id=`alert-user_alert-camera_${day}`;
  const path=`${database}/documents/alerts/${id}`;
  const baseAlert={title:'Dispositivo sin conexión',message:'Cámara de prueba está sin conexión (simulación).',type:'device_offline',deviceId:'alert-camera',userId:'alert-user',read:false};
  const alert=(changes={},docId=id)=>({update:{name:`${database}/documents/alerts/${docId}`,fields:fields({...baseAlert,...changes})},currentDocument:{exists:false},updateTransforms:[{fieldPath:'createdAt',setToServerValue:'REQUEST_TIME'}]});
  const edit=changes=>({update:{name:path,fields:fields(changes)},updateMask:{fieldPaths:Object.keys(changes)}});
  await t.test('creación inicial propia verifica estado real del dispositivo',async()=>{
    allowed(await create('alert-user'));
    allowed(await request(':commit','owner',{writes:[writeDoc('devices','alert-camera',{name:'Cámara de prueba',type:'camera',online:false},{create:true})]}));
    assert.equal((await request(`/alerts/${id}`,'alert-user')).status,404);
    allowed(await request(':commit','alert-user',{writes:[alert()]}));
    allowed(await request(`/alerts/${id}`,'alert-user'));
  });
  await t.test('lectura propia; admin, otros, anónimos e inactivos no leen alertas ajenas',async()=>{
    for(const uid of ['admin','legacy',null,'disabled'])denied(await request(`/alerts/${id}`,uid));
    const query={structuredQuery:{from:[{collectionId:'alerts'}],where:{fieldFilter:{field:{fieldPath:'userId'},op:'EQUAL',value:{stringValue:'alert-user'}}},orderBy:[{field:{fieldPath:'createdAt'},direction:'DESCENDING'}],limit:100}};
    allowed(await request(':runQuery','alert-user',query));
    denied(await request(':runQuery','admin',query));
    denied(await request('/alerts','alert-user'));
  });
  await t.test('solo read=true; contenido, propietario, fecha y borrado protegidos',async()=>{
    for(const change of [{title:'Falso'},{message:'Falso'},{type:'security'},{userId:'admin'},{deviceId:'other'},{createdAt:'yesterday'},{extra:1},{read:'true'}])denied(await request(':commit','alert-user',{writes:[edit(change)]}));
    denied(await request(':commit','admin',{writes:[edit({read:true})]}));
    allowed(await request(':commit','alert-user',{writes:[edit({read:true})]}));
    denied(await request(':commit','alert-user',{writes:[edit({read:false})]}));
    denied(await request(':commit','alert-user',{writes:[{delete:path}]}));
  });
  await t.test('no permite alertas arbitrarias, extra, ajenas ni IDs que eviten deduplicación',async()=>{
    allowed(await create('alert-validation'));
    for(const changes of [{userId:'other'},{title:'Arbitrario'},{message:'Arbitrario'},{type:'security'},{read:true},{extra:'x'}])denied(await request(':commit','alert-validation',{writes:[alert({userId:'alert-validation',...changes},`alert-validation_alert-camera_${day}`)]}));
    denied(await request(':commit','alert-user',{writes:[alert({},'random-id')]}));
    const duplicate=alert();delete duplicate.currentDocument;
    denied(await request(':commit','alert-user',{writes:[duplicate]}));
    assert.equal((await request(`/alerts/${id}`,'alert-user')).body.fields.read.booleanValue,true);
  });
  await t.test('rechaza origen online, tipo no relevante y cuenta inactiva',async()=>{
    allowed(await create('alert-second'));
    const newId=`alert-second_alert-camera_${day}`;
    allowed(await request(':commit','owner',{writes:[writeDoc('devices','alert-camera',{online:true})]}));
    denied(await request(':commit','alert-second',{writes:[alert({userId:'alert-second'},newId)]}));
    allowed(await request(':commit','owner',{writes:[writeDoc('devices','alert-camera',{online:false,type:'light'})]}));
    denied(await request(':commit','alert-second',{writes:[alert({userId:'alert-second'},newId)]}));
    allowed(await update('alert-user',{active:false},'admin'));
    denied(await request(`/alerts/${id}`,'alert-user'));
    denied(await request(':commit','alert-user',{writes:[edit({read:true})]}));
  });
});
