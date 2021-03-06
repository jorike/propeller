{{

WWVB Receiver

V.1.0
Steven R. Stuart, W8AN, Feb 2015
Terms of use are stated at the end of this file.

This software requires a WWVB 60kHz time receiver module.

}}
VAR                                           
    long stack[32] 
    long cog_id
  
PUB Start(wwvb_pin, pulse_buffer, buffer_pointer):status
''  Start/restart the PulseReceiver cog
    Stop
    status := (cog_id := cognew(PulseReceiver(wwvb_pin, pulse_buffer, buffer_pointer), @stack[0])) >0    
    return status

PUB Stop:status  
''  Shutdown the receiver
    if cog_id   
        cogstop(cog_id)      
        cog_id := -1        
    return false
        
PUB PulseReceiver(data_pin, buffer, pointer)| high_time, pulse_width
{{
  Monitors the data_pin for negative pulses, times them and places
  the result into a circular buffer that can be read by some other process
  data_pin: connection to wwvb receiver
  buffer  : is the address of an array of 64 longs, a "circular buffer"
  pointer : is the address of the byte used as the buffer index, a pointer to the most recent data
}}
  dira[data_pin]~                       'input
  byte[pointer] := 0                    'front of buffer  
  ctra := %01000 << 26 + data_pin       'posdet
  ctrb := %01100 << 26 + data_pin       'negdet
  frqa := 1
  frqb := 1
  waitpeq(|< data_pin, |< data_pin, 0)  'sync to input
  waitpeq(0, |< data_pin, 0)
  phsa := 0                             'ready for posdet phase
  waitpne(|< data_pin, |< data_pin, 0)

  repeat                                                  
      phsb := 0                                     'pin is high, posdet phsa advancing, phsb not                                                                
      waitpeq(0 , |< data_pin, 0)                   'pin goes low, phsa stops, phsb starts                                                                    
      high_time := phsa                             'read the pin high time
      phsa := 0                                     'pin is low, negdet phsb advancing, phsa not                                                                 
      waitpeq(|< data_pin, |< data_pin, 0)          'pin goes high, phsb stops, phsa starts                                                                
      pulse_width := high_time*10/8                 'calculate the width of the pulse                                                                                    
      long[buffer][byte[pointer]++] := pulse_width  'store pulse width data into buffer    
      if byte[pointer] > 63                         'buffer wrap around 
          byte[pointer] := 0                    


DAT
{{
┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                             TERMS OF USE: MIT License                                         │                                                                           
├───────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated   │
│documentation files (the "Software"), to deal in the Software without restriction, including without limitation│
│the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,   │
│and to permit persons to whom the Software is furnished to do so, subject to the following conditions:         │                                                         │
│                                                                                                               │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions  │
│of the Software.                                                                                               │
│                                                                                                               │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED  │
│TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL  │
│THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF  │
│CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       │
│DEALINGS IN THE SOFTWARE.                                                                                      │
└───────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}                                