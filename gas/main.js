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

function doPost(e) {
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