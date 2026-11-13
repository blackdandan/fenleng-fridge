import 'client.dart';
class EntitlementSnapshot { final List<Map<String,dynamic>> items; final DateTime fetchedAt; final bool stale; const EntitlementSnapshot(this.items,this.fetchedAt,this.stale); }
class FlutterEntitlementSDK {
  final FenlengFlutterClient client; final String applicationId; final Duration maxAge; EntitlementSnapshot? _snapshot;
  FlutterEntitlementSDK({required this.client,required this.applicationId,this.maxAge=const Duration(minutes:1)});
  Future<EntitlementSnapshot> refresh() async { final page=await client.request('/api/platform/v1/applications/${Uri.encodeComponent(applicationId)}/entitlements/me'); final raw=page['items']; final items=raw is List?raw.cast<Map<String,dynamic>>():<Map<String,dynamic>>[]; return _snapshot=EntitlementSnapshot(items,DateTime.now().toUtc(),false); }
  EntitlementSnapshot current(){final value=_snapshot;if(value==null)return EntitlementSnapshot(const [],DateTime.fromMillisecondsSinceEpoch(0,isUtc:true),true);return EntitlementSnapshot(value.items,value.fetchedAt,DateTime.now().toUtc().difference(value.fetchedAt)>maxAge);}
  bool has(String feature){final value=current();return !value.stale&&value.items.any((item)=>(item['entitlements'] as Map?)?[feature]==true);}
}
