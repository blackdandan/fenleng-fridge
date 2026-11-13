import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const android = path.join(root, '06-project/app/apps/fridge/android');
const directory = path.join(android, 'signing');
const keystore = path.join(directory, 'application-release.jks');
const credentials = path.join(directory, 'credentials.properties');
const approved = process.argv.includes('--apply');
const names = ['keystore', 'store-password', 'key-alias', 'key-password'].map(x => `fenleng-fridge-android-${x}`);
console.log(JSON.stringify({project: 'fenleng-fridge', mode: approved ? 'apply' : 'preview', keystore: path.relative(root, keystore), credentials: path.relative(root, credentials), vaultNames: names, overwrite: false}));
if (!approved) process.exit(0);
if (fs.existsSync(keystore) || fs.existsSync(credentials)) throw new Error('Signing assets already exist; initialization never overwrites them.');
const listing = spawnSync('ssh', ['-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', 'root@121.199.10.6', 'fl-secret list'], {encoding:'utf8',timeout:20000});
if (listing.status !== 0) throw new Error('Vault preflight failed; no signing files created.');
const existing = new Set(listing.stdout.split(/\r?\n/));
if (names.some(name => existing.has(name))) throw new Error('A project signing identity is already registered in Vault; recover it rather than generate a replacement.');
fs.mkdirSync(directory, {recursive:true});
const storePassword = crypto.randomBytes(32).toString('base64url');
const keyPassword = crypto.randomBytes(32).toString('base64url');
const alias = 'fenleng-fridge';
const result = spawnSync('keytool', ['-genkeypair','-noprompt','-keystore',keystore,'-storetype','JKS','-storepass:env','FRIDGE_SIGN_STORE','-keypass:env','FRIDGE_SIGN_KEY','-alias',alias,'-keyalg','RSA','-keysize','3072','-validity','10000','-dname','CN=fenleng-fridge, O=Fenleng, C=CN'], {encoding:'utf8',env:{...process.env,FRIDGE_SIGN_STORE:storePassword,FRIDGE_SIGN_KEY:keyPassword}});
if (result.status !== 0) throw new Error('Keytool initialization failed; inspect local signing assets before retrying.');
fs.writeFileSync(credentials, `storeFile=signing/application-release.jks\nstorePassword=${storePassword}\nkeyAlias=${alias}\nkeyPassword=${keyPassword}\n`, {flag:'wx'});
const exported = spawnSync('keytool', ['-exportcert','-keystore',keystore,'-alias',alias,'-storepass:env','FRIDGE_SIGN_STORE'], {env:{...process.env,FRIDGE_SIGN_STORE:storePassword}});
if (exported.status !== 0) throw new Error('Certificate export failed.');
const cert = new crypto.X509Certificate(exported.stdout);
const record = {
  projectId:'fenleng-fridge', applicationName:'冰箱库存管理', websiteDomain:'fridge.fenlengtech.com',
  android:{applicationId:'com.fenlengtech.fridge',keyAlias:alias,keystorePath:path.relative(root,keystore).replaceAll('\\','/'),credentialsPath:path.relative(root,credentials).replaceAll('\\','/'),certificateFingerprintSha256:cert.fingerprint256,certificateFingerprintSha1:cert.fingerprint,publicKeyPem:cert.publicKey.export({type:'spki',format:'pem'}),vaultNames:names},
  ios:{bundleId:'com.fenlengtech.fridge',teamId:null,certificateId:null,certificateName:null,certificateFingerprintSha256:null,publicKeyPem:null,profileId:null,status:'owner-macos-signing-follow-up'},
  harmonyos:{bundleName:'com.fenlengtech.fridge',appIdentifier:null,status:'owner-platform-registration-follow-up'}
};
const metadata=path.join(root,'05-knowledge/signinfo/application-signing-info.json');
fs.mkdirSync(path.dirname(metadata),{recursive:true});
fs.writeFileSync(metadata,JSON.stringify(record,null,2)+'\n',{flag:'wx'});
console.log('Created fixed signing identity and public metadata. Vault storage is the next explicit step.');
