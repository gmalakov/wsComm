part of shared;

class MessageHandler {
  //Function (data, callback)
  static Map<String, Function> handMap = new Map();

  static void execCommand(String path, dynamic data, Function callBack) {
    if (handMap[path] != null) handMap[path](data, callBack);
     else callBack("ERROR! Function not available!"); //Respond with function not found
  }
}