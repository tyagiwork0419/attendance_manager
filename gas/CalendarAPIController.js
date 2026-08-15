// 取得する年の範囲。現在の年を基準に前後何年ぶんを見るか。
// アプリの日付ピッカーが「今年 ±1年」を選べる（my_home_page.dart）ので、それに合わせている。
const CALENDAR_YEARS_BACK = 1;
const CALENDAR_YEARS_FORWARD = 1;

class CalendarAPIController{
  constructor(useMock = false){
    this._useMock = useMock;
  }

  _getCalendars(){
    if(this._useMock){
      return [new MockCalendar()];
    }
    // 日本の祝日（Google 提供）
    let id1 = "ja.japanese#holiday@group.v.calendar.google.com";

    // 会社の休日カレンダー。
    // 以前は "yagiad.public@gmail.com" を指定していたが、これはそのアカウントの
    // デフォルトカレンダーの ID であり、休日を登録している副カレンダーとは別物。
    // 副カレンダーの ID は @group.calendar.google.com 形式になる。
    let id2 = "50oe6kjcmt9nmjlagbab00af7c@group.calendar.google.com";

    //let id = "tyagiwork0419@gmail.com";
    let ids = [id1, id2];

    let calendars = [];

    for(let i=0; i<ids.length; ++i){
      let calendar = CalendarApp.getCalendarById(ids[i]);

      // 共有が外れている等でアクセスできないと null が返る。
      // そのまま使うと getEvents() で例外になり、他のカレンダーごと
      // 取得が失敗してしまうため、警告を残して読み飛ばす。
      if(calendar === null){
        console.warn('カレンダーにアクセスできないため読み飛ばします: ' + ids[i]);
        continue;
      }

      calendars.push(calendar);
    }

    return calendars;
  }

  getEvents(){
    console.log('getEvents');
    let calendars = this._getCalendars();
    let events = []

    // 現在の年を基準にした範囲。以前は 2023 年で固定されており、
    // 年が変わると祝日が一切返らなくなっていた。
    let currentYear = new Date().getFullYear();
    let startDate = new Date(currentYear - CALENDAR_YEARS_BACK, 0, 1);
    let endDate = new Date(currentYear + CALENDAR_YEARS_FORWARD + 1, 0, 1);

    for(let i=0; i<calendars.length; ++i){
      let calendar = calendars[i];

      let result = calendar.getEvents(startDate, endDate);
      //console.log(result);
      events = events.concat(result);
    }
    
    let dates = [];
    for(let i=0; i<events.length; ++i){
      let event = events[i];
      let dateTime = Utilities.formatDate(event.getStartTime(), AttendData.timezone, AttendData.dateTimeFormat);
      let data = {date : dateTime, name : event.getTitle()};
      dates.push(data);
    }

    return JSON.stringify(dates);
  }
}

class MockEvent{
  constructor(startTime, title){
    this._title = title;
    this._startTime = startTime;
  }

  getTitle(){
    return this._title;
  }

  getStartTime(){
    return this._startTime;
  }
}

class MockCalendar{
  constructor(){
    this._events = [new MockEvent(new Date(2023, 0, 1), '元日')];
  }

  getEvents(startDate, endDate){
    console.log('mock get events');

    let events = this._events.find(function(element){
      let startTime = element.getStartTime();
      //console.log('startTime >= startDate = ' + startTime >= startDate);
      //console.log('startTime <= endDate = ' + startTime <= endDate);
      return (startTime >= startDate) && (startTime <= endDate);
    });
    console.log('events = ' + JSON.stringify(events));
    return events;
  }
}

function getEventsTest(){
  let controller = new CalendarAPIController();
  let res = controller.getEvents();

  console.log(res);
}

