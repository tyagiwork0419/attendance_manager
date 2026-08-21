// 先取りしておく年数。予定の入力が翌年ぶんまで進んでいても拾えるようにする。
// 過去側は「データのある年」から決めるので、ここでは指定しない。
const CALENDAR_YEARS_FORWARD = 1;

class CalendarAPIController{
  constructor(useMock = false){
    this._useMock = useMock;
  }

  /**
   * 取得する年の範囲を決める。
   *
   * データのある年をすべて含め、現在の年と、その先取りぶんも足す。
   * 年の一覧が取れなかった場合でも、現在の年まわりは返せるようにする。
   */
  _yearRange(years){
    let currentYear = new Date().getFullYear();

    let candidates = (years || []).slice();
    candidates.push(currentYear);

    let start = Math.min.apply(null, candidates);
    let end = Math.max.apply(null, candidates.concat([currentYear + CALENDAR_YEARS_FORWARD]));

    return { start: start, end: end };
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

  /**
   * 祝日・会社の休日を返す。
   *
   * [years] は勤怠データのある年の一覧。タイムカードも集計もその範囲を
   * すべて表示できるので、祝日も同じ範囲ぶん揃えておく必要がある。
   * 抜けている年があると、その年の祝日が平日として扱われ、
   * 集計の所定労働時間が過大になる。
   */
  getEvents(years){
    console.log('getEvents');
    let calendars = this._getCalendars();
    let events = []

    let range = this._yearRange(years);
    let startDate = new Date(range.start, 0, 1);
    let endDate = new Date(range.end + 1, 0, 1);
    console.log('calendar range: ' + range.start + ' - ' + range.end);

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

