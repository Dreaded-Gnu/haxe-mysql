package tutorial.connection;

import callfunc.Pointer;
import callfunc.DataType;
import callfunc.Library;
import callfunc.Callfunc;
import mysql.Mysql;

class Sample {
  /**
   * Main entry point
   */
  public static function main():Void {
    // generate new mysql instance
    var mysql:Mysql = new Mysql();
    // connect
    var result:Bool = mysql.connect("127.0.0.1", 3306, "root", "root", null, "test");
    // handle error
    if (false == result) {
      // trace error and errno
      trace(mysql.error());
      trace(mysql.errno());
      // close connection
      mysql.close();
      // skip rest
      return;
    }
    // FIXME: ADD FURTHER SAMPLE CODE
    trace(mysql.escape("foobar"));
    trace(mysql.affectedRows);
    trace(mysql.lastInsertId);
    var result:Dynamic = mysql.query("SELECT * FROM `test`");
    var data:Dynamic;
    while (null != (data = mysql.fetch(result))) {
      trace(data);
    }
    mysql.free(result);
    // close connection
    mysql.close();
  }
}
