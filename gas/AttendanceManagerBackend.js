const DEFAULT_SHEET_ID = "1Y5rlgJU7X0E-i8pNokzDWXXY__AaJr_Ece4JQYOhmgc";

/** シート名が見つからないかった際の使用シート名 */
const DEFAULT_SHEET_NAME = 'template';

const FOLDER_ID = '1Iq5UpbILGSUxZfMFqgCbVk6g75hXqY59';
const TEMPLATE_FILE_ID = '1uycFMLBrmp1Z3BWFV3y_NmQrSasRDBV2OM0qw-G489g';
const TEMPLATE_SHEET_NAME = 'template';
//using spreadsheetsql github(https://github.com/roana0229/spreadsheets-sql)


/**
 * APIコントローラー
 */
class AttendanceManagerBackend {

  constructor(useMock = false) {
    this._useMock = useMock;
  }

  test(){
    let dbId = this._getSheetID(FOLDER_ID, "test");
    let tableName = 'users';

    //let spreadsheet = SpreadsheetApp.openById(dbId);
    //let sheet = spreadsheet.getSheetByName(tableName);

    let SQL = new gSQL();
    let data = SQL.DB(dbId).TABLE(tableName).SELECT(['id','name','password']).WHERE('id','>=', 2).getVal();
    console.log(data);

    SQL.DB(dbId).TABLE(tableName).INSERT(['e', 'ee']);
    console.log('insert!');

    SQL.DB(dbId).TABLE(tableName).UPDATE(['password']).VALUES(['eee']).WHERE('id', '=', 4).setVal();
    console.log('update');
    
  }

  /**
  * 初期化
  * @param e:request変数
  * @param method:string
  */
  _initDB(e) {
    if(this._useMock){
      return new MockDB();
    }

    let sheetId = this._getSheetID(FOLDER_ID, e.fileName);
    let sheetName = e.sheetName;

    let spreadsheet = SpreadsheetApp.openById(sheetId);
    let sheet = spreadsheet.getSheetByName(sheetName);

    if (sheet == null) {
      DriveAppUtility.createSheetFromTemplate(spreadsheet, sheetName);
    }

    
    // 指定スプレッドシートの管理インスタンスを生成
    let db = this._makeTargetSpreadSheetDatabase(
      sheetId,
      sheetName
    );
    

    //let db = new gSQL().DB(sheetId).TABLE(sheetName);

    return db;
  }


  _isSameDay(date1, date2) {
    if (date1.getFullYear() == date2.getFullYear() && date1.getMonth() == date2.getMonth() && date1.getDate() == date2.getDate()) {
      return true;
    } else {
      return false;
    }
  }

  _getFilteredDataListByDate(dataList, date) {

    let elements = [];
    let _this = this;

    dataList.forEach(function (data) {
      if (data.status == Status.deleted) {
        return;
      }

      if (_this._isSameDay(data.dateTime, date)) {
        elements.push(data);
      }
    });

    return elements;
  }

  _getFilteredDataListByName(dataList, name) {
    let elements = [];

    dataList.forEach(function (data) {
      if (data.status == Status.deleted) {
        return;
      }

      if (data.name == name) {
        elements.push(data);
      }
    });

    return elements;
  }

  /**
  * 指定したスプレッドシートの管理インスタンスを作成
  * @return db:SpreadSheetDatabase
  */
  _makeTargetSpreadSheetDatabase(sheetId, sheetName) {

    return SpreadSheetsSQL.open(sheetId, sheetName);
  }

  _makeResponse(dataList) {
    let response = []
    dataList.forEach((data) => {
      response.push(data.toJson());
    });

    return JSON.stringify(response);
  }

  // public functions

  selectByDate(e) {
    try {
      
      let db = this._initDB(e);

      let dateTime = Utilities.parseDate(e.dateTime, AttendData.timezone, AttendData.dateTimeFormat);

      let dataList = this._selectByDate(db, dateTime);

      return this._makeResponse(dataList);
      
    } catch (e) {
      return JSON.stringify(e);
    }
  }

  selectByName(e) {
    try {
      let db = this._initDB(e);

      let name = e.name;

      let dataList = this._selectByName(db, name);
      return this._makeResponse(dataList);
    } catch (e) {
      console.log('error: ' + e);
      return JSON.stringify(e);
    }

  }

  insertRows(e) {
    try {
      console.log('insert rows. param = ' + JSON.stringify(e));
      
      let db = this._initDB(e);
      let data = e.postData;
      let id = this._getNextId(db);
      //let dateTime = Utilities.parseDate(data.dateTime, AttendData.timezone, AttendData.dateTimeFormat);
      data.id = id
      //data.dateTime = dateTime;

      let newData = AttendData.fromJson(data);
      console.log('new data = ' + JSON.stringify(newData.toJson()));
      db.insertRows([newData.toJson()]);

      let dataList = this._selectByDate(db, newData.dateTime);

      return this._makeResponse(dataList);
    } catch (e) {
      console.log('error: ' + e);
      return JSON.stringify(e);
    }
  }

  updateById(e) {
    try {
      console.log('update by id. param = ' + JSON.stringify(e));
      let db = this._initDB(e);

      let id = e.postData.id;
      let status = e.postData.status;
      let dateTime = Utilities.parseDate(e.postData.dateTime, AttendData.timezone, AttendData.dateTimeFormat);

      db.updateRows({ 'status': status }, 'id = ' + id);

      let dataList = this._selectByDate(db, dateTime);

      return this._makeResponse(dataList);
    } catch (e) {
      console.log('error: ' + e);
      return JSON.stringify(e);
    }
  }
}

function test1() {
  const controller = new SpreadSheetAPIController();

  controller.test();
  //let dataList = [new AttendData(1, 'a', AttendType.clockIn, new Date(), Status.normal)];
  //let result = controller._getFilteredDataListByDate(dataList, new Date());

  //console.log(result);
}

function insertRowsTest() {
  const controller = new SpreadSheetAPIController();

  let e = { 'fileName': 'test', 'sheetName': 'test', 'postData': { 'id': 0, 'name': 'test', 'type': '出勤', 'dateTime': '2023/07/27 01:01:00', 'status': 'normal' } };
  let result = controller.insertRows(e);

  console.log(result);
}



function selectByDateTest() {
  const controller = new SpreadSheetAPIController();
  let e = { 'fileName': '2023年', 'sheetName': '7月', 'dateTime': '2023/07/28 00:00:00' };

  result = controller.selectByDate(e);
  console.log(result);
}