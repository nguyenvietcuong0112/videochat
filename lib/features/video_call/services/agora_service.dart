
import 'package:agora_token_service/agora_token_service.dart';

class AgoraService {
  final String _appId = '12f3721389824634afc36132b35d33a7';
  final String _appCertificate = 'a791a89352e847c98e21e4a6e30847b3';

  Future<String> getToken(String channelName, int uid) async {
    const int privilegeExpireTimeInSeconds = 3600; // Token valid for 1 hour
    final int currentTime = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final int expireTimestamp = currentTime + privilegeExpireTimeInSeconds;

    // Use the RtcTokenBuilder from the package to generate the token
    return RtcTokenBuilder.build(
      appId: _appId,
      appCertificate: _appCertificate,
      channelName: channelName,
      uid: uid.toString(), // UID must be a string now
      role: RtcRole.publisher, // The user role, e.g., publisher or subscriber
      expireTimestamp: expireTimestamp,
    );
  }
}
