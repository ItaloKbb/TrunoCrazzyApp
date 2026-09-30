enum LobbyStatus { idle, loading, success, failure }

class LobbyState  {
  const LobbyState._({required this.status, this.error});
}