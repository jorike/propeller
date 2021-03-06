{{

                **************************************************
                          Kalman Filter V1.0        
                **************************************************
                   coded by Jason Wood jtw.programmer@gmail.com        
                ************************************************** 
                         other coders has been noted
                **************************************************

┌──────────────────────────────────────────┐
│ Copyright (c) 2008 Jason T Wood          │               
│     See end of file for terms of use.    │               
└──────────────────────────────────────────┘

          


/
 both state_update and kalman_update functions comments accredited to ...
 * $Id: tilt.c,v 1.1 2003/07/09 18:23:29 john Exp $
 *
 * 1 dimensional tilt sensor using a dual axis accelerometer
 * and single axis angular rate gyro.  The two sensors are fused
 * via a two state Kalman filter, with one state being the angle
 * and the other state being the gyro bias.
 *
 * Gyro bias is automatically tracked by the filter.  This seems
 * like magic.
 *
 * Please note that there are lots of comments in the functions and
 * in blocks before the functions.  Kalman filtering is an already complex
 * subject, made even more so by extensive hand optimizations to the C code
 * that implements the filter.  I've tried to make an effort of explaining
 * the optimizations, but feel free to send mail to the mailing list,
 * autopilot-devel@lists.sf.net, with questions about this code.
 *
 * 
 * (c) 2003 Trammell Hudson <hudson@rotomotion.com>
 *
 *************
 *
 *  This file is part of the autopilot onboard code package.
 *  
 *  Autopilot is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *  
 *  Autopilot is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with Autopilot; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */          
}}
CON
  
  {/*
  * Our update rate. This is how often our state is updated with
  * gyro rate measurements. For now, we do it every time an
  * 8 bit counter running at CLK/1024 expires. You will have to
  * change this value if you update at a different rate.
  */}
  'dt = 0.0200500
  ' Calculated each state_update call  
  
  {/*
  * R represents the measurement covariance noise. In this case,
  * it is a 1x1 matrix that says that we expect 0.3 rad jitter
  * from the accelerometer.
  */}
  R_angle = 0.3

  {/*
  * Q is a 2x2 matrix that represents the process covariance noise.
  * In this case, it indicates how much we trust the acceleromter
  * relative to the gyros.
  */}
  Q_angle = 0.3
  Q_gyro = 0.001

  
OBJ

  fMath         :               "FloatMath"         
    
VAR
  
  {/*
  * Our two states, the angle and the gyro bias. As a byproduct of computing
  * the angle, we also have an unbiased angular rate available.  These are
  * read-only to the user of the module.
  */}

  long P[4]  

  {/*
  * Our covariance matrix. This is updated at every time step to
  * determine how well the sensors are tracking the actual state.
  */}
  long Pdot[4]

  ' Kalman filtered variables
  long q_bias
  long rate
  long angle

  long lastTime
  long lastAngle
  long totalRevolutions

  long firstRun
  
pub start
{{
  Assign the ADC pens on the Prop then
  start the COG to run the kalman filter
  returning the cog's ID
}}

  ' Initilize floating vars
  q_bias := 0.0 {35 uS} 
  angle := 0.0 {35 uS} 
  rate := 0.0 {35 uS} 
  
  P[0] := 1.0 {35 uS} 
  P[1] := 0.0 {35 uS} 
  P[2] := 0.0 {35 uS} 
  P[3] := 1.0 {35 uS} 

  Pdot[0] := 0.0 {35 uS} 
  Pdot[1] := 0.0 {35 uS} 
  Pdot[2] := 0.0 {35 uS} 
  Pdot[3] := 0.0 {35 uS}

  totalRevolutions := 0
  lastAngle := 0.0
  firstRun := 0

pub get_angle
{{
  Return the current Kalman Filtered angle as a Float in Degrees
}}
  return angle
  
pub get_q_bias
{{
  Return the current q_bias of the gyro as a Float
}}
  return q_bias
  
pub get_rate
{{
  Return the current biased rate of the gyro as a Float in Degrees/sec
}}
  return rate

pub get_Revolutions
{{
  Return and Integer of the total times the unit has spun in a full 360 rotation.
}}
  return totalRevolutions
 
pub state_update(q_m) | q, dt

{/*
 * state_update is called every dt with a biased gyro measurement
 * by the user of the module.  It updates the current angle and
 * rate estimate.
 *
 * The tch gyro measurement should be scaled into real units, but
 * does not need any bias removal.  The filter will track the bias.
 *
 * Our state vector is:
 *
 *      X = [ angle, gyro_bias ]
 *
 * It runs the state estimation forward via the state functions:
 *
 *      Xdot = [ angle_dot, gyro_bias_dot ]
 *
 *      angle_dot       = gyro - gyro_bias
 *      gyro_bias_dot   = 0
 *
 * And updates the covariance matrix via the function:
 *
 *      Pdot = A*P + P*A' + Q
 *
 * A is the Jacobian of Xdot with respect to the states:
 *
 *      A = [ d(angle_dot)/d(angle)     d(angle_dot)/d(gyro_bias) ]
 *          [ d(gyro_bias_dot)/d(angle) d(gyro_bias_dot)/d(gyro_bias) ]
 *
 *        = [ 0 -1 ]
 *          [ 0  0 ]
 *
 * Due to the small CPU available on the microcontroller, we've
 * hand optimized the C code to only compute the terms that are
 * explicitly non-zero, as well as expanded out the matrix math
 * to be done in as few steps as possible.  This does make it harder
 * to read, debug and extend, but also allows us to do this with
 * very little CPU time.
 */}

  {/* Unbias our gyro */}
  q := fMath.FSub(q_m, q_bias) {39 uS} 

  {/*
   * Compute the derivative of the covariance matrix
   *
   *            Pdot = A*P + P*A' + Q
   *
   * We've hand computed the expansion of A = [ 0 -1, 0 0 ] multiplied
   * by P and P multiplied by A' = [ 0 0, -1, 0 ].        This is then added
   * to the diagonal elements of Q, which are Q_angle and Q_gyro.
   */}                                        
     
  Pdot[0] := fMath.FSub(fMath.FSub( Q_angle, P[1] ), P[2]) {39 uS}  
  Pdot[1] := fMath.FNeg(P[3]) {21 uS}
  Pdot[2] := fMath.FNeg(P[3]) {21 uS}  
  Pdot[3] := Q_gyro  {35 uS} 
                                        
  {/* Store our unbias gyro estimate */}
  rate := q

  dt := fMath.FDiv(fMath.FFloat(cnt-lastTime), fMath.FFloat(clkfreq))
  
  {/*
   * Update our angle estimate
   * angle += angle_dot * dt
   *             += (gyro - gyro_bias) * dt
   *             += q * dt
   */}   
  angle := fMath.FAdd(angle, fMath.FMul(q, dt) {46 uS} )  {39 uS} 

  {/* Update the covariance matrix */}                
  P[0] := fMath.FAdd(P[0], fMath.FMul(Pdot[0], dt) {46 uS} ) {39 uS} 
  P[1] := fMath.FAdd(P[1], fMath.FMul(Pdot[1], dt) {46 uS} ) {39 uS} 
  P[2] := fMath.FAdd(P[2], fMath.FMul(Pdot[2], dt) {46 uS} ) {39 uS} 
  P[3] := fMath.FAdd(P[3], fMath.FMul(Pdot[3], dt) {46 uS} ) {39 uS} 

  lastTime := cnt
  
pub kalman_update(angle_m {ax_m, az_m}) | {angle_m,} PCt_0, PCt_1,  K_0, K_1, t_0, t_1, E, angle_err
{/*
 * kalman_update is called by a user of the module when a new
 * accelerometer measurement is available.  ax_m and az_m do not
 * need to be scaled into actual units, but must be zeroed and have
 * the same scale.
 *
 * This does not need to be called every time step, but can be if
 * the accelerometer data are available at the same rate as the
 * rate gyro measurement.
 *
 * For a two-axis accelerometer mounted perpendicular to the rotation
 * axis, we can compute the angle for the full 360 degree rotation
 * with no linearization errors by using the arctangent of the two
 * readings.
 *
 * As commented in state_update, the math here is simplified to
 * make it possible to execute on a small microcontroller with no
 * floating point unit.  It will be hard to read the actual code and
 * see what is happening, which is why there is this extensive
 * comment block.
 *
 * The C matrix is a 1x2 (measurements x states) matrix that
 * is the Jacobian matrix of the measurement value with respect
 * to the states.  In this case, C is:
 *
 *      C = [ d(angle_m)/d(angle)  d(angle_m)/d(gyro_bias) ]
 *        = [ 1 0 ]
 *
 * because the angle measurement directly corresponds to the angle
 * estimate and the angle measurement has no relation to the gyro
 * bias.
 */}


  {

  NOT FINISHED! This would handle angles going beyond +-180 degree 
  
  if firstRun > 0
    if fMath.FAbs(fMath.FSub(angle_m, lastAngle)) > 300.0
      if lastAngle < angle_m
        totalRevolutions -= 1
      else
        totalRevolutions += 1
  else
    firstRun := 1
    
  lastAngle := angle_m

  angle_m := fMath.FAdd(fMath.FFloat(180*totalRevolutions), fMath.FAdd( fMath.FFloat(180*totalRevolutions) , angle_m))
  
  }

  {/* Compute our measured angle and the error in our estimate */}   
  'angle_m := fMath.ATan2(fMath.FNeg(ax_m) {21 uS} , az_m) {183 uS}
  
  angle_err := fMath.FSub(angle_m, angle) {39 uS}

  
  {/*
   * C_0 shows how the state measurement directly relates to
   * the state estimate.
   *
   * The C_1 shows that the state measurement does not relate
   * to the gyro bias estimate.        We don't actually use this, so
   * we comment it out.
   */}
  'C_0 := fMath.FFloat(1.0) {35 uS} 

  {/*
   * PCt<2,1> = P<2,2> * C'<2,1>, which we use twice.        This makes
   * it worthwhile to precompute and store the two values.
   * Note that C[0,1] = C_1 is zero, so we do not compute that
   * term.
   */ }
  PCt_0 := fMath.FMul(1.0, P[0]) {46 uS} 
  PCt_1 := fMath.FMul(1.0, P[2]) {46 uS}

   
  {/*
   * Compute the error estimate.        From the Kalman filter paper:
   *       
   *            E = C P C' + R
   *       
   * Dimensionally,
   *
   *            E<1,1> = C<1,2> P<2,2> C'<2,1> + R<1,1>
   *
   * Again, note that C_1 is zero, so we do not compute the term.
   */}   
  E := fMath.FAdd(R_angle, fMath.FMul(1.0, PCt_0) {46 uS} )  {39 uS} 


  {/*
   * Compute the Kalman filter gains.        From the Kalman paper:
   *
   *            K = P C' inv(E)
   *
   * Dimensionally:
   *
   *            K<2,1> = P<2,2> C'<2,1> inv(E)<1,1>
   *
   * Luckilly, E is <1,1>, so the inverse of E is just 1/E.
   */}
  K_0 := fMath.FDiv(PCt_0, E) {45 uS} 
  K_1 := fMath.FDiv(PCt_1, E) {45 uS} 

  {/*
   * Update covariance matrix.        Again, from the Kalman filter paper:
   *
   *            P = P - K C P
   *
   * Dimensionally:
   *
   *            P<2,2> -= K<2,1> C<1,2> P<2,2>
   *
   * We first compute t<1,2> = C P.        Note that:
   *
   *            t[0,0] = C[0,0] * P[0,0] + C[0,1] * P[1,0]
   *
   * But, since C_1 is zero, we have:
   *
   *            t[0,0] = C[0,0] * P[0,0] = PCt[0,0]
   *
   * This saves us a floating point multiply.
   */}   
  t_0 := PCt_0 
  t_1 := fMath.FMul(1.0, P[1]) {46 uS} 

  P[0] := fMath.FSub(P[0], fMath.FMul(K_0, t_0) {46 uS} ) {39 uS}
  P[1] := fMath.FSub(P[1], fMath.FMul(K_0, t_1) {46 uS} ) {39 uS}
  P[2] := fMath.FSub(P[2], fMath.FMul(K_1, t_0) {46 uS} ) {39 uS}
  P[3] := fMath.FSub(P[3], fMath.FMul(K_1, t_1) {46 uS} ) {39 uS}

    
  {/*
   * Update our state estimate.        Again, from the Kalman paper:
   *
   *            X += K * err
   *
   * And, dimensionally,
   *
   *            X<2> = X<2> + K<2,1> * err<1,1>
   *
   * err is a measurement of the difference in the measured state
   * and the estimate state.        In our case, it is just the difference
   * between the two accelerometer measured angle and our estimated
   * angle.
   */}
   
  angle := fMath.FAdd( angle, fMath.FMul(K_0, angle_err) {46 uS} ) {39 uS}  
  q_bias := fMath.FAdd( q_bias, fMath.FMul(K_1, angle_err) {46 uS} ) {39 uS}


{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}     