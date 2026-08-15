const exports = GASUnit.exports
const assert = GASUnit.assert

function _isSameDay(date1, date2) {
    if (date1.getFullYear() == date2.getFullYear() && date1.getMonth() == date2.getMonth() && date1.getDate() == date2.getDate()) {
      return true;
    } else {
      return false;
    }
}
 
function test() {
  let fileName = 'test';
  let sheetName = 'test';
  exports({
    'test public methods': {
      'selectByDate': () => {
        let controller = new SpreadSheetAPIController(true);
        let dateTime = Utilities.formatDate(new Date(2023,0,1), AttendData.timezone, AttendData.dateTimeFormat);
        let e = {fileName: fileName, sheetName: sheetName, dateTime: dateTime};
        let res = JSON.parse(controller.selectByDate(e));

        console.log('res = ' + JSON.stringify(res));

        let result = true;
        for(let i=0; i<res.length; ++i){
          let date1 = Utilities.parseDate(res[i].dateTime, AttendData.timezone, AttendData.dateTimeFormat);
          let date2 = Utilities.parseDate(dateTime, AttendData.timezone, AttendData.dateTimeFormat);
          if(!_isSameDay(date1, date2)){
            result = false;
            break;
          }
        }
        assert(result === true);
      },

      'selectByName': () => {
        let controller = new SpreadSheetAPIController(true);
        let name = 'test1';
        let e = {fileName: fileName, sheetName: sheetName, name: name};
        let res = JSON.parse(controller.selectByName(e));
        console.log('res = ' + JSON.stringify(res));

        let result = true;
        for(let i=0; i<res.length; ++i){
          if(res[i].name != name){
            result = false;
            break;
          }
        }
        assert(result === true);
      },

      'insertRows': () => {
        let controller = new SpreadSheetAPIController(true);
        let dateTime = Utilities.formatDate(new Date(2023,0,1), AttendData.timezone, AttendData.dateTimeFormat);
        console.log('dateTime = ' + dateTime);
        let e = {fileName: fileName, sheetName: sheetName, postData: {id: 4, name: 'test1', type: '出勤', dateTime: dateTime, status: 'normal'}};
        let res = JSON.parse(controller.insertRows(e));
        console.log('res = ' + JSON.stringify(res));
        assert(res[res.length -1].id === 4);
      },

      'updateById': () => {
        let controller = new SpreadSheetAPIController(true);
        let dateTime = Utilities.formatDate(new Date(2023,0,1), AttendData.timezone, AttendData.dateTimeFormat);
        let id = 3;
        let e = {fileName: fileName, sheetName: sheetName, postData: {id: id, dateTime: dateTime, status: 'deleted'}};
        let res = JSON.parse(controller.updateById(e));
  
        console.log('res = ' + JSON.stringify(res));
        let finded = res.find((element) => element.id == id);

        console.log('finded = ' + JSON.stringify(finded));
        assert(finded === undefined);
      },
    },
    'test private methods': {
      'Hello world!': () => {
        //assert(hello('world!') === 'Hello world!')
      }
    } 
  })
}