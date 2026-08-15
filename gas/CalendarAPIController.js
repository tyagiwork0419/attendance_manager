class CalendarAPIController{
  constructor(useMock = false){
    this._useMock = useMock;
  }

  _getCalendars(){
    if(this._useMock){
      return [new MockCalendar()];
    }
    let id1 = "ja.japanese#holiday@group.v.calendar.google.com";
    let id2 = "yagiad.public@gmail.com";
    //let id = "tyagiwork0419@gmail.com";
    let ids = [id1, id2];

    let calendars = [];

    for(let i=0; i<ids.length; ++i){
      let calendar = CalendarApp.getCalendarById(ids[i]);
      calendars.push(calendar);
    }

    return calendars;
  }

  getEvents(){
    console.log('getEvents');
    let calendars = this._getCalendars();
    let events = []
    
    for(let i=0; i<calendars.length; ++i){
      let calendar = calendars[i];
      let startDate = new Date(2023, 0, 1);
      let endDate = new Date(2023, 11, 31);

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

