"""Native source/merged-manifest checks; not runtime or iOS compilation proof."""
from pathlib import Path
import json
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2]
app = root / '06-project/app/apps/fridge'
android = app / 'android/app/src/main'
ios = app / 'ios/Runner'
read = lambda p: p.read_text(encoding='utf-8')
generated = read(android / 'java/io/flutter/plugins/GeneratedPluginRegistrant.java')
deferred = read(android / 'kotlin/com/fenlengtech/fridge/DeferredPluginRegistrant.kt')
generated_classes = set(re.findall(r'new ([\w.]+)\(', generated))
deferred_classes = set(re.findall(r'engine.plugins.add\(([\w.]+)\(', deferred))
assert generated_classes == deferred_classes, (generated_classes, deferred_classes)
local = deferred.split('fun registerLocal', 1)[1].split('fun registerGlobal', 1)[0]
assert 'firebase.' not in local and 'googlesignin.' not in local
assert 'if (china)' in local
activity = read(android / 'kotlin/com/fenlengtech/fridge/MainActivity.kt')
assert 'GeneratedPluginRegistrant.registerWith' not in activity
online = activity.split('"plugins.initializeOnline" ->', 1)[1].split('"data.directory" ->', 1)[0]
for condition in ['activeReleaseChannel == "global"', '"policyVersion"', '"releaseChannel"', '"acceptedAt"', '"withdrawalPending"']:
    assert condition in online, condition
manifest = app / 'build/app/intermediates/merged_manifest/debug/processDebugMainManifest/AndroidManifest.xml'
tree = ET.parse(manifest)
ns = '{http://schemas.android.com/apk/res/android}'
providers = [e.attrib.get(ns+'name') for e in tree.findall('.//provider')]
assert 'com.google.firebase.provider.FirebaseInitProvider' not in providers
generated_ios = set(re.findall(r'\[(\w+) registerWithRegistrar:', read(ios / 'GeneratedPluginRegistrant.m')))
deferred_ios = read(ios / 'FridgeDeferredPluginRegistrant.m')
assert generated_ios == set(re.findall(r'\[(\w+) registerWithRegistrar:', deferred_ios))
assert 'GeneratedPluginRegistrant.register(with:' not in read(ios / 'AppDelegate.swift')
pbx = read(app / 'ios/Runner.xcodeproj/project.pbxproj')
assert 'FridgeDeferredPluginRegistrant.m in Sources' in pbx
assert 'IPHONEOS_DEPLOYMENT_TARGET = 13.0;' not in pbx
assert "platform :ios, '15.0'" in read(app / 'ios/Podfile')
config = json.loads(read(root / '03-deployment/config/firebase-global.example.json'))
assert config['FRIDGE_FIREBASE_ENABLED'] is False
assert config['FRIDGE_FIREBASE_PROJECT_ID'].startswith('fenleng-fridge-')
print(json.dumps({'status':'passed','scope':'Android compiled merged manifest and Android/iOS source registration inventories; not native runtime/iOS compile',
    'androidPluginClasses':sorted(generated_classes),'iosPluginClasses':sorted(generated_ios),
    'firebaseAutoInitializerAbsent':True,'iosMinimum':'15.0','defaultFirebaseEnabled':False}, indent=2))
