part of shared;

class Message {
  static bool _server = false;

  static set server(bool srv) => _server = srv;

  static int counter = 0;

  static const String pth_ = "path";
  static const String id_ = "id";
  static const String msg_ = "msg";

  int id;
  dynamic msg;
  String pth;
  Function handler;

  //Handler function will be used on client side only

  Message(this.msg, this.pth, this.handler, {int id}) {
    if (id != null) this.id = id;
    else {
      //Generate new id if not passed from constructor
      if (_server) counter--; //On server counter will decrease -1, -2, -3
      else counter++;
      //On client counter will increase 1,2,3

      this.id = counter;
    }
  }

  Message.fromJson(String data) {
    Map inMap;
    try {
      inMap = JSON.decode(data);
    } catch (err) {}
    if (inMap != null) {
      id = inMap[id_];
      msg = inMap[msg_];
      pth = inMap[pth_];
    }
  }

  Map toMap() => { id_: id, msg_:msg, pth_:pth};

  Map toJson() => toMap();

  String toString() => toMap().toString();

}

class MsgCache {
  static const int maxSec = 20;
  static const String errMsg = "Error! TimeOut sending message.";

  Map<int, Message> _cache = new Map();
  Map<int, DateTime> _usage = new Map();

  Message findMsg(Message cMsg) {
    if ((_cache == null) || (cMsg == null)) return null;
    return _cache[cMsg?.id];
  }

  void setMsg(Message cMsg) {
    _cache[cMsg?.id] = cMsg;
    _usage[cMsg?.id] = new DateTime.now();

    rmOld();
  }

  void rmOld() {
    List<int> toDel = new List();
    DateTime now = new DateTime.now();

    //Find old items
    for (int i in _usage.keys)
        if (now.difference(_usage[i]).inSeconds >= maxSec) toDel.add(i);

    //Remove found items
    for (int i in toDel) try {
      if (_cache[i].handler != null) _cache[i].handler(errMsg);
      _cache.remove(i);
      _usage.remove(i);
    } catch (err) {}
  }

  bool remove(int id) {
    if (_cache[id] == null) return false;
    try {
      _cache.remove(id);
      _usage.remove(id);
    } catch (err) {}

    return true;
  }


}
