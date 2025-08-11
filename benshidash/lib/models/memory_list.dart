import '../benshi/protocol/data_models.dart';

class MemoryList {
  final String name;
  final List<Channel> channels;

  MemoryList({required this.name, required this.channels});

  factory MemoryList.fromJson(Map<String, dynamic> json) {
    var channelsList = json['channels'] as List;
    List<Channel> parsedChannels = channelsList
        .map((c) => Channel.fromJson(c as Map<String, dynamic>))
        .toList();

    // --- FIX: Remap channels to ensure channelId is always 0-indexed and sequential ---
    // This ignores the "channelId" from the JSON file and uses the list order instead,
    // which is what the radio expects for writing.
    List<Channel> remappedChannels = [];
    for (int i = 0; i < parsedChannels.length; i++) {
      remappedChannels.add(parsedChannels[i].copyWith(channelId: i));
    }

    return MemoryList(
      name: json['name'],
      channels: remappedChannels,
    );
  }
}