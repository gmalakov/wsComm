import 'package:wscomm/client.dart';
import 'dart:html';
import 'dart:convert';

WSClient wsc;

void login([MouseEvent ev]) {

  wsc.sendMessage("login", {"username": "svc", "password": "svc2"}).then((res)
  {
    if (res is String) try { res = JSON.decode(res); } catch (err) { res = new Map(); }
    wsc.sesid = res["login"];
    querySelector("#result").innerHtml = res.toString();
  });

}

void getRep([MouseEvent ev]) {
  String sid = querySelector("#rid").value;
  int id;
  try { id = int.parse(sid);} catch (err) { id = 1; }
  wsc.sendMessage("FindRep", {"id": id }).then((res) {
    //if (res is String) try { res = JSON.decode(res); } catch (err) { res = new Map(); }
    querySelector("#result").innerHtml = res.toString();
  });
}

void main() {
  wsc = new WSClient("ws://127.0.0.1:9876/ws", "1A2B2D4A1DDD");
  querySelector("#login").onClick.listen(login);
  querySelector("#getrep").onClick.listen(getRep);
}