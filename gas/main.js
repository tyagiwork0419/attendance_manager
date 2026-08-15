// Apps Script は全ファイルを1つのグローバルスコープに連結して評価するため、
// トップレベルで他ファイルのクラスを new すると評価順に依存する。
// GAS はファイルをアルファベット順で保持しており main は
// SpreadSheetAPIController より前に来るので、トップレベルで new すると
// ReferenceError になる。clasp の filePushOrder でも制御できない。
// 呼び出し時に初期化することで、評価順に依存しないようにしている。
var controller = null;
var calendarController = null;

function initControllers_() {
  if (controller === null) {
    controller = new SpreadSheetAPIController();
    calendarController = new CalendarAPIController();
  }
}

function doGet(e) {
  try{
    initControllers_();
    let result = controller.handleGet(e);
    //return Response(result);
    return JSON.stringify(result);
  } catch(error) {
    //return Abort(error);
    errorResponse = {
      error:{
        message:error.message
      }
    }
    return JSON.stringify(errorResponse);
  }
}

// Web アプリのエントリポイントは Auth.gs の doPost に一本化した。
// Apps Script は全ファイルが単一のグローバルスコープを共有するため、
// doPost が複数あると後から読み込まれた定義が勝ち、どちらが有効になるかが
// ファイルの並び順に依存してしまう。衝突を避けるため改名してある。
// （この関数は戻り値が無く、Web アプリの応答としては機能しない。
//   旧クライアントは doPost ではなく scripts.run API を使っていた。）
function legacyDoPost_(e) {
  initControllers_();
  controller.handlePost(e);
}



function selectByDate(e){
  console.log(e);
  initControllers_();
  result = controller.selectByDate(e);
  return result;
}

function selectByName(e){
  console.log(e);
  initControllers_();
  result = controller.selectByName(e);
  return result;
}

function insertRows(e){
  initControllers_();
  result = controller.insertRows(e);
  return result;
}

function updateById(e){
  initControllers_();
  result = controller.updateById(e);
  return result;
}

function getEvents(e){
  initControllers_();
  result = calendarController.getEvents();
  return result;
}

function getInitializeData(e){
  e = {'fileName':'2023年', 'sheetName':'7月', 'dateTime':'2023/07/28 00:00:00'};
  let datas = selectByDate(e);
  let events = getEvents(e);
  let result = '{' + '"datas":' + datas + ',"events":' + events + '}';
  console.log('result = ' + result);

  return result;
}
