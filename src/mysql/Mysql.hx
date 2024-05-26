package mysql;

import haxe.DynamicAccess;
import callfunc.StructAccess;
import callfunc.StructAccess.StructAccessImpl;
import haxe.display.Display.FieldResolution;
import haxe.Exception;
import haxe.io.Bytes;
import haxe.Int64;
import callfunc.Pointer;
import callfunc.DataType;
import callfunc.Library;
import callfunc.Callfunc;

@:keepInit
class Mysql {
  public var lastInsertId(default, never):Int;
  public var affectedRows(default, never):Int;

  private var ffi:Callfunc;
  private var lib:Library;
  private var mysql:Pointer;

  public function new() {
    // get ffi instance
    this.ffi = Callfunc.instance();
    // get library
    this.lib = ffi.openLibrary("libmariadb.so");
    // define functions to be used
    lib.define("mysql_init", [DataType.Pointer,], DataType.Pointer);
    lib.define("mysql_real_connect", [
      DataType.Pointer,
      DataType.Pointer,
      DataType.Pointer,
      DataType.Pointer,
      DataType.Pointer,
      DataType.SInt32,
      DataType.Pointer,
      DataType.ULong
    ], DataType.Pointer);
    lib.define("mysql_error", [DataType.Pointer], DataType.Pointer);
    lib.define("mysql_errno", [DataType.Pointer], DataType.Pointer);
    lib.define("mysql_close", [DataType.Pointer], DataType.Void);
    lib.define("mysql_real_escape_string", [DataType.Pointer, DataType.Pointer, DataType.Pointer, DataType.ULong], DataType.ULong);
    lib.define("mysql_affected_rows", [DataType.Pointer], DataType.ULong);
    lib.define("mysql_insert_id", [DataType.Pointer], DataType.ULong);
    lib.define("mysql_rollback", [DataType.Pointer], DataType.Pointer);
    lib.define("mysql_commit", [DataType.Pointer], DataType.Pointer);
    lib.define("mysql_autocommit", [DataType.Pointer, DataType.UInt8], DataType.Pointer);
    lib.define("mysql_real_query", [DataType.Pointer, DataType.Pointer, DataType.ULong], DataType.SInt);
    lib.define("mysql_num_fields", [DataType.Pointer], DataType.UInt);
    lib.define("mysql_store_result", [DataType.Pointer], DataType.Pointer);
    lib.define("mysql_field_count", [DataType.Pointer], DataType.UInt);
    lib.define("mysql_fetch_field_direct", [DataType.Pointer, DataType.UInt], DataType.Pointer);
    lib.define("mysql_free_result", [DataType.Pointer], DataType.Void);
    lib.define("mysql_fetch_row", [DataType.Pointer], DataType.Pointer);
    // call mysql init1
    this.mysql = lib.s.mysql_init.call(ffi.getPointer(0));
  }

  /**
   * Connect to database
   * @param host
   * @param port
   * @param user
   * @param pass
   * @param socket
   * @param database
   * @return Bool
   */
  public function connect(host:String, ?port:Int, user:String, pass:String, ?socket:String, ?database:String):Bool {
    if (port == null) {
      port = 3306;
    }
    // generate pointer for ffi call
    var hostPointer:Pointer = this.ffi.allocString(host);
    var userPointer:Pointer = this.ffi.allocString(user);
    var passwordPointer:Pointer = this.ffi.allocString(pass);
    var databasePointer:Pointer = database != null ? this.ffi.allocString(database) : this.ffi.getPointer(0);
    var socketPointer:Pointer = socket != null ? this.ffi.allocString(socket) : this.ffi.getPointer(0);
    // connect
    var connection:Pointer = this.lib.s.mysql_real_connect.call(this.mysql, hostPointer, userPointer, passwordPointer, databasePointer, port, socketPointer, 0);
    // handle error
    return !connection.isNull();
  }

  /**
   * Close mysql again
   */
  public function close():Void {
    this.lib.s.mysql_close.call(mysql);
  }

  /**
   * Errno function
   * @return Int
   */
  public function errno():Int {
    var errnoPointer:Pointer = this.lib.s.mysql_errno.call(mysql);
    return Int64.toInt(errnoPointer.address);
  }

  /**
   * Error function
   * @return String
   */
  public function error():String {
    var errorPointer:Pointer = this.lib.s.mysql_error.call(mysql);
    return errorPointer.getString();
  }

  /**
   * Escape string using real escape string
   * @param val
   * @return String
   */
  public function escape(val:String):String {
    var len:Int = val.length * 2 + 1;
    var valPointer:Pointer = this.ffi.allocString(val);
    var resultPointer:Pointer = this.ffi.alloc(len);
    this.lib.s.mysql_real_escape_string.call(this.mysql, resultPointer, valPointer, val.length);
    return resultPointer.getString();
  }

  /**
   * Quote string
   * @param val
   * @return String
   */
  public function quote(val:String):String {
    return '"${escape(val)}"';
  }

  /**
   * Begin a transaction
   * @return Bool
   */
  public function begin():Bool {
    var result:Pointer = this.lib.s.mysql_autocommit.call(this.mysql, 0);
    return Int64.toInt(result.address) == 0;
  }

  /**
   * Commit a transaction
   * @return Bool
   */
  public function commit():Bool {
    // perform rollback
    var result:Pointer = this.lib.s.mysql_commit.call(this.mysql);
    // reenable auto commit
    this.lib.s.mysql_autocommit.call(this.mysql, 1);
    // return result
    return Int64.toInt(result.address) == 0;
  }

  /**
   * Rollback transaction
   * @return Bool
   */
  public function rollback():Bool {
    // perform rollback
    var result:Pointer = this.lib.s.mysql_rollback.call(this.mysql);
    // reenable auto commit
    this.lib.s.mysql_autocommit.call(this.mysql, 1);
    // return result
    return Int64.toInt(result.address) == 0;
  }

  /**
   * Request from database
   * @param query
   * @return Pointer
   */
  public function query(query:String):Dynamic {
    var queryPointer:Pointer = this.ffi.allocString(query);
    var queryResult:Int = this.lib.s.mysql_real_query.call(this.mysql, queryPointer, query.length);
    if (queryResult != 0) {
      throw new Exception('Query ${query} failed.');
    }
    // get stored result
    var storedResult:Pointer = this.lib.s.mysql_store_result.call(this.mysql);
    if (storedResult.isNull()) {
      var fieldCountResult:UInt = this.lib.s.mysql_field_count.call(this.mysql);
      if (0 == fieldCountResult) {
        return null;
      }
      throw new Exception('Query result fetch for ${query} failed.');
    }
    // return mysql result
    return storedResult;
  }

  /**
   * Fetch a row from result
   * @param result
   * @return Dynamic
   */
  public function fetch(result:Dynamic):Dynamic {
    // define mysql field result structure
    var mysqlFieldResultStructure = this.ffi.defineStruct([
      DataType.Pointer, DataType.UInt, DataType.Pointer, DataType.UInt, DataType.Pointer, DataType.UInt, DataType.Pointer, DataType.UInt, DataType.Pointer,
      DataType.UInt, DataType.Pointer, DataType.UInt, DataType.Pointer, DataType.UInt, DataType.UInt, DataType.UInt, DataType.UInt, DataType.UInt,
      DataType.SInt
    ], [
      "name", "name_length", "org_name", "org_name_length", "table", "table_length", "org_table", "org_table_length", "db", "db_length", "catalog",
      "catalog_length", "def", "def_length", "length", "max_length", "flags", "decimals", "type"
    ]);

    // dynamic for return
    var o:DynamicAccess<Dynamic> = {};
    // map of fields by index
    var fieldByIndex:Map<Int, String> = new Map<Int, String>();
    // data types and fields for later mysql_fetch_row
    var dataTypes:Array<DataType> = [];
    var fields:Array<String> = [];

    // fetch fields and prepare structor
    var numFields:UInt = this.lib.s.mysql_num_fields.call(result);
    for (i in 0...numFields) {
      // get field result pointer
      var fieldResultPointer:Pointer = this.lib.s.mysql_fetch_field_direct.call(result, i);
      // access field structure
      var fieldResult:StructAccess = mysqlFieldResultStructure.access(fieldResultPointer);
      // get name
      var name:String = cast(fieldResult.get("name"), Pointer).getString();
      // set name in structure
      o.set(name, null);
      // set field by index
      fieldByIndex.set(i, name);
      // push data type for result structure
      dataTypes.push(DataType.Pointer);
      fields.push(Std.string(i));
    }

    // define mysql result structure
    var mysqlResultStructure = this.ffi.defineStruct(dataTypes, fields);
    // call mysql fetch row
    var resultPointer:Pointer = this.lib.s.mysql_fetch_row.call(result);
    // access via earlier build mysql result structure
    var result:StructAccess = mysqlResultStructure.access(resultPointer);
    // loop through num fields
    for (i in 0...numFields) {
      // get field by index
      var field:String = fieldByIndex.get(i);
      // get value from num field0
      var value:String = cast(result.get(Std.string(i)), Pointer).getString();
      // set value within dynamic
      o.set(field, value);
    }

    return o;
  }

  /**
   * Free result again
   * @param result
   */
  public function free(result:Dynamic):Void {
    this.lib.s.mysql_free_result.call(result);
  }

  /**
   * Getter for last insert id property
   * @return UInt
   */
  private function get_lastInsertId():UInt {
    return this.lib.s.mysql_affected_rows.call(this.mysql);
  }

  /**
   * Getter for affected rows property
   * @return UInt
   */
  private function get_affectedRows():UInt {
    return this.lib.s.mysql_affected_rows.call(this.mysql);
  }
}
