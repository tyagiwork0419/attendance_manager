const controller = new SpreadSheetAPIController();
const calendarController = new CalendarAPIController();

function doGet(e) {
  try{
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
  controller.handlePost(e);
}



function selectByDate(e){
  console.log(e);
  result = controller.selectByDate(e);
  return result;
}

function selectByName(e){
  console.log(e);
  result = controller.selectByName(e);
  return result;
}

function insertRows(e){
  result = controller.insertRows(e);
  return result;
}

function updateById(e){
  result = controller.updateById(e);
  return result;
}

function getEvents(e){
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