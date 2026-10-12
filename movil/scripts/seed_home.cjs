// Explicit development seed. No Firebase project is created. No client admin rights.
const path = require('node:path');
const areas = [ ['sala','Sala'], ['cocina','Cocina'], ['recamara','Recámara'], ['bano','Baño'], ['patio','Patio'] ];
const devices = [
  ['light_sala_1','Luz Sala','light','sala',true,75],
  ['light_sala_2','Luz Sala auxiliar','light','sala',true,50],
  ['light_cocina','Luz Cocina','light','cocina',true,100],
  ['light_recamara_1','Luz Recámara','light','recamara',true,50],
  ['light_recamara_2','Luz Recámara auxiliar','light','recamara',true,25],
  ['light_bano','Luz Baño','light','bano',false,100],
  ['camera_patio','Cámara Patio','camera','patio',true,0],
  ['fan_sala','Ventilador Sala','fan','sala',false,1],
  ['ac_recamara','Aire Recámara','airConditioner','recamara',false,24],
  ['lock_patio','Cerradura Patio','lock','patio',true,0],
  ['sensor_patio','Sensor Patio','sensor','patio',true,22],
];
const wattsByType={light:9,fan:60,airConditioner:1200,camera:8,lock:2,sensor:1};
async function seedPowers(client,project,apply=false){
  if(!['ecohome-3c91d','demo-ecohome-rules'].includes(project))throw new Error('Proyecto no permitido.');
  const base=`/projects/${project}/databases/(default)/documents`;
  const {transaction}=await client.post(`${base}:beginTransaction`,{});let committed=false;
  try{
    const rows=await client.post(`${base}:batchGet`,{transaction,documents:devices.map(d=>`${base.slice(1)}/devices/${d[0]}`)});
    const writes=[];
    for(const row of rows){if(!row.found)continue;
      const doc=row.found,field=doc.fields.energyConsumption;
      if(Number(field?.doubleValue??field?.integerValue)!==0)continue;
      const demo=devices.find(d=>d[0]===doc.name.split('/').pop());
      if(doc.fields.type.stringValue!==demo[2])continue;
      writes.push({update:{name:doc.name,fields:fields({energyConsumption:wattsByType[demo[2]]})},
        updateMask:{fieldPaths:['energyConsumption']},updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]});
    }
    if(!writes.length)return {status:'skipped',devices:0};
    if(!apply)return {status:'preview',devices:writes.length};
    await client.post(`${base}:commit`,{transaction,writes});committed=true;return {status:'updated',devices:writes.length};
  }finally{if(!committed)await client.post(`${base}:rollback`,{transaction});}
}
function encode(value) {
  if(Array.isArray(value))return {arrayValue:{values:value.map(encode)}};
  if(typeof value==='object' && value!==null)return {mapValue:{fields:fields(value)}};
  return typeof value==='boolean' ? {booleanValue:value} : typeof value==='number'
    ? {doubleValue:value} : {stringValue:value};
}
function fields(values) {return Object.fromEntries(Object.entries(values).map(([key,value])=>[key,encode(value)]));}
const action=(deviceId,enabled,value)=>({deviceId,enabled,...(value===undefined?{}:{value})});
const lights=devices.filter(device=>device[2]==='light').map(device=>device[0]);
const scenes=[
  {id:'modo_noche',name:'Modo Noche',actions:[
    ...lights.map(id=>action(id,id==='light_recamara_2',id==='light_recamara_2'?15:0)),
    action('lock_patio',true),action('camera_patio',true)]},
  {id:'modo_casa',name:'Modo Casa',actions:[
    action('light_sala_1',true,75),action('light_sala_2',true,50),action('light_cocina',true,100),
    action('light_recamara_1',true,50),action('lock_patio',true),action('camera_patio',true)]},
  {id:'modo_away',name:'Modo Away',actions:[
    ...lights.map(id=>action(id,false)),action('fan_sala',false),action('ac_recamara',false),
    action('lock_patio',true),action('camera_patio',true)]},
  {id:'ahorro_energia',name:'Ahorro de Energía',actions:[
    ...lights.map(id=>action(id,id==='light_sala_1',id==='light_sala_1'?30:0)),
    action('fan_sala',false),action('ac_recamara',false)]},
];

async function seedScenes(client,project,apply=false) {
  if(!['ecohome-3c91d','demo-ecohome-rules'].includes(project))throw new Error('Proyecto no permitido.');
  const base=`/projects/${project}/databases/(default)/documents`;
  const {transaction}=await client.post(`${base}:beginTransaction`,{});
  let committed=false;
  try {
    const current=await client.post(`${base}:batchGet`,{
      documents:scenes.map(scene=>`${base.slice(1)}/scenes/${scene.id}`),transaction});
    const missing=new Set(current.filter(row=>row.missing).map(row=>row.missing.split('/').pop()));
    const pending=scenes.filter(scene=>missing.has(scene.id));
    if(!pending.length)return {status:'skipped',scenes:0};
    const ids=[...new Set(pending.flatMap(scene=>scene.actions.map(action=>action.deviceId)))];
    const refs=await client.post(`${base}:batchGet`,{documents:ids.map(id=>`${base.slice(1)}/devices/${id}`),transaction});
    for(const row of refs){
      if(row.missing)throw new Error(`Falta dispositivo demo: ${row.missing.split('/').pop()}. No se escribe nada.`);
      const id=row.found.name.split('/').pop();
      if(row.found.fields.type.stringValue!==devices.find(device=>device[0]===id)[2])throw new Error(`Tipo modificado: ${id}. No se escribe nada.`);
    }
    if(!apply)return {status:'preview',scenes:pending.length};
    await client.post(`${base}:commit`,{transaction,writes:pending.map(scene=>({
      update:{name:`${base.slice(1)}/scenes/${scene.id}`,fields:fields({name:scene.name,enabled:true,actions:scene.actions})},
      currentDocument:{exists:false},
      updateTransforms:['createdAt','updatedAt'].map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'})),
    }))});
    committed=true;return {status:'created',scenes:pending.length};
  }finally{if(!committed)await client.post(`${base}:rollback`,{transaction});}
}
async function seedHome(client, project, apply = false) {
  if (!['ecohome-3c91d','demo-ecohome-rules'].includes(project)) throw new Error('Proyecto no permitido.');
  const base = `/projects/${project}/databases/(default)/documents`;
  const {transaction} = await client.post(`${base}:beginTransaction`,{});
  let committed = false;
  try {
    for (const collection of ['areas','devices']) {
      const rows = await client.post(`${base}:runQuery`, {
        structuredQuery:{from:[{collectionId:collection}],limit:1}, transaction,
      });
      if (rows.some(row=>row.document)) return {status:'skipped',reason:'Ya existen áreas o dispositivos; no se modifica nada.'};
    }
    if (!apply) return {status:'preview',areas:areas.length,devices:devices.length};
    const documents = [
      ...areas.map(([id,name])=>({collection:'areas',id,data:{name}})),
      ...devices.map(([id,name,type,areaId,enabled,value])=>({collection:'devices',id,
        data:{name,type,areaId,enabled,value,online:true,energyConsumption:wattsByType[type]}})),
    ];
    await client.post(`${base}:commit`,{transaction,writes:documents.map(doc=>({
      update:{name:`${base.slice(1)}/${doc.collection}/${doc.id}`,fields:fields(doc.data)},
      currentDocument:{exists:false},
      updateTransforms:['createdAt','updatedAt'].map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'})),
    }))});
    committed=true;
    return {status:'created',areas:areas.length,devices:devices.length};
  } finally {
    if (!committed) await client.post(`${base}:rollback`,{transaction});
  }
}
module.exports={seedHome,seedScenes,seedPowers,scenes,fields};

if(require.main===module) {
  (async()=>{
    const args=process.argv.slice(2);
    if(args.some(arg=>!['--apply','--scenes','--powers'].includes(arg)) || (args.includes('--scenes')&&args.includes('--powers'))) throw new Error('Uso: node scripts/seed_home.cjs [--scenes | --powers] [--apply]');
    if(process.env.FIRESTORE_EMULATOR_HOST) throw new Error('El comando real no se ejecuta con FIRESTORE_EMULATOR_HOST.');
    const base=path.join(process.env.APPDATA,'npm/node_modules/firebase-tools/lib');
    const auth=require(path.join(base,'auth.js'));
    const {requireAuth}=require(path.join(base,'requireAuth.js'));
    const {Client}=require(path.join(base,'apiv2.js'));
    await requireAuth({project:'ecohome-3c91d',...auth.getProjectDefaultAccount(process.cwd())});
    const api=new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1'});
    const client={post:async(url,body)=>(await api.post(url,body)).body};
    const seed=args.includes('--scenes')?seedScenes:args.includes('--powers')?seedPowers:seedHome;
    console.log(JSON.stringify(await seed(client,'ecohome-3c91d',args.includes('--apply')),null,2));
  })().catch(error=>{ console.error(error.message); process.exitCode=1; });
}
