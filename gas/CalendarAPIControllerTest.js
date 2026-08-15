
function test() {
  exports({
    'test public methods': {
      'getEvents': () => {
        let controller = new CalendarAPIController(true);
        let events = controller.getEvents();
        
        console.log('res = ' + events);

        
        assert(JSON.parse(events)[0].name === '元日');
      },

      
    },
    'test private methods': {
      'Hello world!': () => {
        //assert(hello('world!') === 'Hello world!')
      }
    } 
  })
}