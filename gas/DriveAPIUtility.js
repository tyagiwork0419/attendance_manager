class DriveAppUtility{

  static checkFileExists(folderId, fileName){
    let folder = DriveApp.getFolderById(folderId);
    let files = folder.getFilesByName(fileName);
    return files.hasNext();
  }

  static createFileFromTemplate(fileName, folderId, templateFileId) {
    
    let template = DriveApp.getFileById(templateFileId);
    
    if(DriveAppUtility.checkFileExists(folderId, fileName)){
      throw new SameNameError("this file has same name");
    }
    let file = template.makeCopy(fileName);
    console.log('create file. filename = ' + fileName);
    return file;
  }

  // spreadsheet
  static createSheetFromTemplate(spreadsheet, sheetName, templateSheetName) {
    console.log('create sheet. sheetName = ' + sheetName);
    let template = spreadsheet.getSheetByName(templateSheetName);
    let copySheet = template.copyTo(spreadsheet);
    let sheets = spreadsheet.getSheets();
    for(var i=0; i<sheets.length; ++i){
      if(sheets[i].getName() == sheetName){
        throw new SameNameError('this spreadsheet has same sheet name');
      }
    }
    copySheet.setName(sheetName);

    return copySheet;
  }

  static getFileIdByName(folderId, fileName) {
    let folder = DriveApp.getFolderById(folderId);
    let files = folder.getFilesByName(fileName);

    if (!files.hasNext()) {
      throw new NotFoundError('no such file: ' + fileName + ', from folder id: ' + folderId);
    }

    let id = files.next().getId();
    return id;
  }
}

class SameNameError extends Error{
  constructor(message){
    super(message);
    this.name = 'SameNameError';
  }
}

class NotFoundError extends Error{
  constructor(message){
    super(message);
    this.name = 'NotFoundError';
  }
}
  

function createFileTest() {
  let fileName = 'test';
  let templateFileId = '1KoZdrArjzORX8ZjTPheXzAs094Ptuj79-fVdRrnP068';
  let folderId = '1pqiTDqLmwcS_M8R_qhSo5F8tzxApy3b4';
  let file;
  try{
    file = DriveAppUtility.createFileFromTemplate(fileName, folderId, templateFileId);
    console.log('file name = ' + file.getName());

    
  }catch(error){
    if(error instanceof SameNameError){
      console.log('SameNameError: ' + error.message);
      fileName = fileName + " 1"
      file = DriveAppUtility.createFileFromTemplate(fileName, folderId, templateFileId);
    }else{
      console.log('General Error: ' + error.message);
    }
  }

  if(file != undefined){
    file.setTrashed(true);
  }
  
  
}

//spreadsheet
function createSheetFromTemplateTest() {
  let sheetId = '1CFjY4SOCpWmCh2qDoenKSJr1FpniPRRpApFtT40lej4';
  let fileName = 'test';
  let templateSheetName = 'template';

  let spreadsheet = SpreadsheetApp.openById(sheetId);
  let sheet = DriveAppUtility.createSheetFromTemplate(spreadsheet, fileName, templateSheetName);

  console.log('sheet name = ' + sheet.getSheetName());
}

function getFileIdByNameTest() {
  let folderId = '1pqiTDqLmwcS_M8R_qhSo5F8tzxApy3b4';
  let fileName = 'test';
  let sheetId = DriveAppUtility.getFileIdByName(folderId, fileName);

  console.log('sheetId = ' + sheetId);

}