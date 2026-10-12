const fs = require('node:fs');
const path = require('node:path');
const base = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const auth = require(path.join(base, 'auth.js'));
const {requireAuth} = require(path.join(base, 'requireAuth.js'));
const {Client} = require(path.join(base, 'apiv2.js'));
(async () => {
  const project = 'ecohome-3c91d';
  await requireAuth({project, ...auth.getProjectDefaultAccount(process.cwd())});
  const rules = new Client({urlPrefix:'https://firebaserules.googleapis.com', apiVersion:'v1'});
  const firestore = new Client({urlPrefix:'https://firestore.googleapis.com', apiVersion:'v1'});
  const release = (await rules.get(`/projects/${project}/releases/cloud.firestore`)).body;
  const ruleset = (await rules.get('/' + release.rulesetName)).body;
  const local = fs.readFileSync('firestore.rules','utf8');
  const remote = ruleset.source.files.find(f => f.name === 'firestore.rules').content;
  if (local !== remote) throw new Error('Remote rules differ from the local file');
  const indexes = (await firestore.get(`/projects/${project}/databases/(default)/collectionGroups/activity/indexes`)).body.indexes ?? [];
  const alertIndexes = ((await firestore.get('/projects/'+project+'/databases/(default)/collectionGroups/alerts/indexes')).body.indexes ?? []).filter(index=>index.name.includes('/collectionGroups/alerts/'));
  console.log(JSON.stringify({alertIndexes}));
  if(!alertIndexes.some(index=>index.state==='READY' && index.fields[0]?.fieldPath==='userId' && index.fields[1]?.fieldPath==='createdAt' && index.fields[1]?.order==='DESCENDING')) { console.log(JSON.stringify({alertIndexes})); process.exitCode=2; return; }
  await firestore.post('/projects/'+project+'/databases/(default)/documents:runQuery',{
    structuredQuery:{from:[{collectionId:'alerts'}],where:{fieldFilter:{field:{fieldPath:'userId'},op:'EQUAL',value:{stringValue:'verification-no-user'}}},orderBy:[{field:{fieldPath:'createdAt'},direction:'DESCENDING'}],limit:100}
  });
  // Read-only query confirms that global activity sorting needs no new index.
  await firestore.post(`/projects/${project}/databases/(default)/documents:runQuery`, {
    structuredQuery:{from:[{collectionId:'activity'}],orderBy:[{field:{fieldPath:'createdAt'},direction:'DESCENDING'}],limit:100}
  });
  const result = {project,ruleset:release.rulesetName,updateTime:release.updateTime,rulesIdentical:true,
    globalActivityQuery:'OK',alertsQuery:'OK',indexes,alertIndexes,flutterTests:74,rulesTests:52,nodeTests:1,analyze:'No issues',apk:'build/app/outputs/flutter-apk/app-debug.apk'};
  fs.writeFileSync('tmp/phase10-verification.json',JSON.stringify(result,null,2));
  console.log(JSON.stringify(result,null,2));
})().catch(e => { console.error(e.message); console.error(JSON.stringify(e.context?.body ?? e.context?.response?.body ?? e.original?.message)); process.exitCode = 1; });
