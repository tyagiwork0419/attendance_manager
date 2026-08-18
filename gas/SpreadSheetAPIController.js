//const DEFAULT_SHEET_ID = "1Y5rlgJU7X0E-i8pNokzDWXXY__AaJr_Ece4JQYOhmgc";

/** シート名が見つからないかった際の使用シート名 */
//const DEFAULT_SHEET_NAME = 'template';

//const FOLDER_ID = '1Iq5UpbILGSUxZfMFqgCbVk6g75hXqY59';
//const TEMPLATE_FILE_ID = '1uycFMLBrmp1Z3BWFV3y_NmQrSasRDBV2OM0qw-G489g';
//const TEMPLATE_SHEET_NAME = 'template';
//using spreadsheetsql github(https://github.com/roana0229/spreadsheets-sql)


/**
 * APIコントローラー
 */
class SpreadSheetAPIController {

  constructor(dbId, sheetId, useMock = false) {
    this._useMock = useMock;
  }

  test(){
    let dbId = this._getSheetID(FOLDER_ID, "test");
    let tableName = this._getTargetSheetNameFromData('users');

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
      this._createSheetFromTemplate(spreadsheet, sheetName);
    }

    
    // 指定スプレッドシートの管理インスタンスを生成
    let db = this._makeTargetSpreadSheetDatabase(
      sheetId,
      sheetName
    );
    
    //let db = new gSQL().DB(sheetId).TABLE(sheetName);

    return db;
  }

  _selectByDate(db, date) {
    console.log('select by date. date = ' + date );

    let dataList = [];

    // _initDB が返すのは SpreadSheetsSQL のインスタンス。
    // 旧 gSQL の API (SELECT / getVal) は持たないため _selectByName と同じ呼び方に揃える。
    let rows = db.select(AttendData.getPropertyNames()).result();

    rows.forEach(function (row) {
      //console.log(row);
      let dateTime = Utilities.formatDate(row.dateTime, AttendData.timezone, AttendData.dateTimeFormat);
      row.dateTime = dateTime;
      dataList.push(AttendData.fromJson(row));
    });

    dataList = this._getFilteredDataListByDate(dataList, date);

    return dataList;
  }

  _selectByName(db, name) {
    console.log('select by name. name = ' + name);

    let dataList = [];

    let rows = db.select(AttendData.getPropertyNames()).result();

    rows.forEach(function (row) {
      let dateTime = Utilities.formatDate(row.dateTime, AttendData.timezone, AttendData.dateTimeFormat);
      row.dateTime = dateTime;
      dataList.push(AttendData.fromJson(row));
    });

    dataList = this._getFilteredDataListByName(dataList, name);

    return dataList;
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

  _getNextId(db) {
    
    let ids = db.select(['id']).result();
    if (ids.length == 0) {
      return 1;
    }
    let nextId = ids[ids.length - 1]['id'] + 1;
    return nextId;
  }

  _getSheetID(folderId, fileName) {
    let folder = DriveApp.getFolderById(folderId);
    let files = folder.getFilesByName(fileName);

    if (!files.hasNext()) {
      let file = this._createFileFromTemplate(fileName);
      return file.getId();
    }

    let id = files.next().getId();
    return id;
  }

  /**
  * 指定されたシート名を取得
  * @param data:object
  * @return sheet:string
  */
  _getTargetSheetNameFromData(sheetName) {
    return sheetName;
  }

  _createFileFromTemplate(fileName) {
    console.log('create file. filename = ' + fileName);
    let template = DriveApp.getFileById(TEMPLATE_FILE_ID);
    let file = template.makeCopy(fileName);
    return file;
  }

  _createSheetFromTemplate(spreadsheet, sheetName) {
    console.log('create sheet. sheetName = ' + sheetName);
    let template = spreadsheet.getSheetByName(TEMPLATE_SHEET_NAME);
    let copySheet = template.copyTo(spreadsheet);
    copySheet.setName(sheetName);

    return copySheet;
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

    } catch (error) {
      // 握り潰さず Auth.gs の doPost まで送出する。
      // JSON.stringify(Error) は "{}" になり、原因が失われたうえ
      // HTTP 200 の正常応答として返ってしまうため。
      console.error('selectByDate error: ' + error);
      throw error;
    }
  }

  /**
   * データのある年を昇順で返す。
   *
   * 年ごとに「2026年」という名前のファイルを作る運用なので、
   * フォルダ内のファイル名から年を拾う。
   *
   * 画面側で選べる範囲をこれに合わせると、存在しない年を開いて
   * _getSheetID がテンプレートから空ファイルを作ってしまうのを防げる。
   */
  listYears() {
    let folder = DriveApp.getFolderById(FOLDER_ID);
    let files = folder.getFiles();

    let years = [];
    while (files.hasNext()) {
      let matched = files.next().getName().match(/^(\d{4})年$/);
      if (matched) {
        years.push(Number(matched[1]));
      }
    }

    years.sort(function (a, b) {
      return a - b;
    });

    return JSON.stringify(years);
  }

  /**
   * 1年分（ファイル内の全シート）をまとめて返す。
   *
   * 集計ページは12か月ぶんを必要とするが、月ごとに呼ぶと往復が12回になる。
   * ここでまとめることで1回で済ませる。
   *
   * _initDB は月シートが無いとテンプレートから作ってしまうため使わない。
   * 実在するシートだけを読む。
   */
  selectByNameForYear(e) {
    try {
      let sheetId = this._getSheetID(FOLDER_ID, e.fileName);
      let spreadsheet = SpreadsheetApp.openById(sheetId);
      let sheets = spreadsheet.getSheets();

      let dataList = [];
      for (let i = 0; i < sheets.length; ++i) {
        let sheetName = sheets[i].getName();
        if (sheetName == TEMPLATE_SHEET_NAME) {
          continue;
        }

        let db = this._makeTargetSpreadSheetDatabase(sheetId, sheetName);
        dataList = dataList.concat(this._selectByName(db, e.name));
      }

      return this._makeResponse(dataList);
    } catch (error) {
      console.error('selectByNameForYear error: ' + error);
      throw error;
    }
  }

  selectByName(e) {
    try {
      let db = this._initDB(e);

      let name = e.name;

      let dataList = this._selectByName(db, name);
      return this._makeResponse(dataList);
    } catch (error) {
      // 握り潰さず Auth.gs の doPost まで送出する。
      // JSON.stringify(Error) は "{}" になり、原因が失われたうえ
      // HTTP 200 の正常応答として返ってしまうため。
      console.error('error: ' + error);
      throw error;
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
    } catch (error) {
      // 握り潰さず Auth.gs の doPost まで送出する。
      // JSON.stringify(Error) は "{}" になり、原因が失われたうえ
      // HTTP 200 の正常応答として返ってしまうため。
      console.error('error: ' + error);
      throw error;
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
    } catch (error) {
      // 握り潰さず Auth.gs の doPost まで送出する。
      // JSON.stringify(Error) は "{}" になり、原因が失われたうえ
      // HTTP 200 の正常応答として返ってしまうため。
      console.error('error: ' + error);
      throw error;
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

function createFileTest() {
  const controller = new SpreadSheetAPIController();

  controller._createFileFromTemplate('test');
}

function createSheetTest() {
  const controller = new SpreadSheetAPIController();

  controller._createSheetFromTemplate('test', 'test');
}

function selectByDateTest() {
  const controller = new SpreadSheetAPIController();
  let e = { 'fileName': '2023年', 'sheetName': '7月', 'dateTime': '2023/07/28 00:00:00' };

  result = controller.selectByDate(e);
  console.log(result);
}

class MockDB {
  constructor() {
    this._dataList = [];
    this._dataList.push(new AttendData(1, 'test1', AttendType.clockIn, new Date(2023, 0, 1), Status.normal, '').toJson());
    this._dataList.push(new AttendData(2, 'test1', AttendType.clockIn, new Date(2023, 0, 2), Status.normal, '').toJson());
    this._dataList.push(new AttendData(3, 'test2', AttendType.clockIn, new Date(2023, 0, 1), Status.normal, '').toJson());


  }

  select(columnList) {
    let result = [];
    for (let i = 0; i < this._dataList.length; ++i) {
      let data = this._dataList[i];
      let element = {};
      for (let j = 0; j < columnList.length; ++j) {
        let key = columnList[j];
        let value = data[key];
        element[key] = value;
      }
      result.push(element);
    }

    return new MockResponse(result);
  }

  insertRows(data) {
    for (let i = 0; i < data.length; ++i) {
      let row = data[i];
      this._dataList.push(row);
    }
  }

  updateRows(data, filter) {
    let strs = filter.split(' ');
    let filterKey = strs[0];
    let operator = strs[1];
    let filterValue = strs[2];

    this._dataList.forEach(function (element) {
      switch (operator) {
        case '=':
          if (element[filterKey] == filterValue) {

            Object.keys(data).forEach(function (key) {
              element[key] = data[key];
            });
          }
          break;
      }
    });
  }

}

class MockResponse {
  constructor(result) {
    this._result = result;
  }

  result() {
    return this._result;
  }
}

function mockDBTest() {
  let db = new MockDB();

  let res = db.select(AttendData.getPropertyNames()).result();
  console.log('select: ' + JSON.stringify(res));

  db.insertRows([new AttendData(4, 'test2', AttendType.clockIn, new Date(2023, 0, 2), Status.normal, '').toJson()]);
  res = db.select(AttendData.getPropertyNames()).result();
  console.log('insertRows: ' + JSON.stringify(res));

  db.updateRows({ 'status': Status.deleted }, 'id = ' + 4);
  res = db.select(AttendData.getPropertyNames()).result();
  console.log('updateRows: ' + JSON.stringify(res));


}