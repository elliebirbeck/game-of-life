/////////////////////////////////////////////////////////////////////////////////////////
//
// COMS20001
/*
   * Game Of Life.xc
   *
   *  Created on: 14 Nov 2014
   *      Author: eb13817
*/
//
/////////////////////////////////////////////////////////////////////////////////////////

typedef unsigned char uchar;

#include <platform.h>
#include <math.h>
#include <stdio.h>
#include "pgmIO.h"
#define IMHT 64
#define IMWD 64
#define BTNA 14
#define BTNB 13
#define BTNC 11
#define BTND 7
in port  buttons = PORT_BUTTON;
out port cled0 = PORT_CLOCKLED_0;
out port cled1 = PORT_CLOCKLED_1;
out port cled2 = PORT_CLOCKLED_2;
out port cled3 = PORT_CLOCKLED_3;
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;

int showLED(out port p, chanend fromVisualiser) {
  unsigned int lightUpPattern;
  while (1) {
    fromVisualiser :> lightUpPattern; //read LED pattern from visualiser process
    if(lightUpPattern==-2) return 0;
    p <: lightUpPattern;              //send pattern to LEDs
  }
  return 0;
}


void visualiser (chanend fromDistributor, chanend toQuadrant0, chanend toQuadrant1, chanend toQuadrant2, chanend toQuadrant3) {
  int integer= 0;
  cledG <: 1;
  int dec;
  while(1){
      fromDistributor :> integer;
      if(integer==-2){
          //recieved shut down signal
          //tell Quadrants to shut Down
          toQuadrant0<:integer;
          toQuadrant1<:integer;
          toQuadrant2<:integer;
          toQuadrant3<:integer;

          return;
      }
      if(integer>4095){
          //if the value is to big to display sets colour to red
          cledR <: 1;
          cledG <: 0;
          //divide number by the image width to display average live cells per row;
          integer= (integer/IMWD);
          if(integer>4095){
              integer=4095;
              //if the number is still to big to display even after reducing it, then we leave all lights on.
          }
      }else{

          cledR <: 0;
          cledG <: 1;

      }
      int binaryNumber[12];
      dec = integer;
      for(int j=0;j<12;j++){
          binaryNumber[j]=0;
      }
      int count =0;
      while(dec>0)
          {
            binaryNumber[count]=dec%2;
            count++;
            dec=dec/2;
          }

        int q[4];
        for(int i=0; i<4; i++){
          q[i]=0;
          //increment through the four quadrants
          if (binaryNumber[(3*i)] == 1) {
              //if the first binary digit in this quadrant is 1, add 16 to the quadrant display value
              q[i] += 16;
          }
          if (binaryNumber[((3*i)+1)] == 1) {
              //if the second binary digit in this quadrant is 1, add 32 to the quadrant display value
              q[i] += 32;
           }
          if (binaryNumber[((3*i)+2)] == 1) {
            //if the third binary digit in this quadrant is 1, add 64 to the quadrant display value
            q[i] += 64;
          }

        }
        //send the calculated quadrant values to each quadrant
        toQuadrant0 <:q[0];
        toQuadrant1 <:q[1];
        toQuadrant2 <:q[2];
        toQuadrant3 <:q[3];
  }
}



void buttonListener(in port b, chanend toDistributor) {
  int r;
  while(1){
      select {
          case toDistributor :> r:
              if(r==-2){
                  //shutdown signal
                  return;
              }
              break;
          case b when pinsneq(15) :> r:
              toDistributor <: r;            // send button pattern to distributor
              b when pinseq(15) :> r;    // check that button isnt pressed
          break;
      }
  }

}


/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from pgm file with path and name infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////

void DataInStream(chanend c_out)
{
  char infname[] = "test64.pgm";
  int res;
  uchar line[ IMWD ];
  printf( "DataInStream:Start...\n" );
  res = _openinpgm( infname, IMWD, IMHT );
  if( res )
  {
    printf( "DataInStream:Error opening %s\n.", infname );
    return;
  }
  for( int y = 0; y < IMHT; y++ )
  {
    _readinline( line, IMWD );
    for( int x = 0; x < IMWD; x++ )
    {
      c_out <: line[ x ];
      //printf( "-%4.1d ", line[ x ] ); //uncomment to show image values
    }
    //printf( "\n" ); //uncomment to show image values
  }
  _closeinpgm();
  printf( "DataInStream:Done...\n" );
  return;
}


/////////////////////////////////////////////////////////////////////////////////////////
//
// distributor thread which farms out the work
//
/////////////////////////////////////////////////////////////////////////////////////////

void distributor(chanend toVisualiser, chanend c_in, chanend c_out, chanend fromButtons, chanend workerChanTL, chanend workerChanTR, chanend workerChanBL, chanend workerChanBR)
{
      int buttonInput;
      int turn = 0;
      //wait for button press of A before starting the process
      while (buttonInput!=BTNA) {
          fromButtons :> buttonInput;
      }

      uchar val;
      printf( "ProcessImage:Start, size = %dx%d\n", IMHT, IMWD );

      //sends each worker thread a quarter of the matrix of pixels
      for(int y = 0; y < IMHT; y++ ) {
          for( int x = 0; x < IMWD; x++ ) {
               c_in :> val;
               if ((x<(IMWD/2))&&(y<(IMHT/2))) {
                   workerChanTL <: val;
               }
               else if ((x>=(IMWD/2))&&(y<(IMHT/2))) {
                   workerChanTR <: val;
               }
               else if ((x<(IMWD/2))&&(y>=(IMHT/2))) {
                   workerChanBL <: val;
               }
               else if ((x>=(IMWD/2))&&(y>=(IMHT/2))) {
                   workerChanBR <: val;
               }

         }
     }


     //storage for the pixels which need to be communicated between cores
     uchar TLright[IMHT/2];
     uchar TLbottom[IMHT/2];
     uchar TLcorner;
     uchar TRleft[IMHT/2];
     uchar TRbottom[IMHT/2];
     uchar TRcorner;
     uchar BLright[IMHT/2];
     uchar BLtop[IMHT/2];
     uchar BLcorner;
     uchar BRleft[IMHT/2];
     uchar BRtop[IMHT/2];
     uchar BRcorner;
     int noOfLiveCells=0; // the number of cells live
     int live;
     int signal=0;


     while(1){

         select{

             case fromButtons :> buttonInput :
                switch(buttonInput){
                case BTNA :

                    break;
                case BTNB :
                    //when button B is pressed the game is paused
                    toVisualiser <: turn; //turn is sent to the visualiser
                    fromButtons :> buttonInput;
                    while(buttonInput!=BTNB){
                        //program waits for another press of button B
                        fromButtons :> buttonInput;
                    }
                    toVisualiser<:0;
                    break;
                case BTNC :
                    //Button C sets signal to -1 which means export
                    signal = -1;
                    break;
                case BTND :
                    //shutdown all processes
                    signal=-2;
                    fromButtons  <: signal;
                    workerChanTL <: signal;
                    workerChanTR <: signal;
                    workerChanBL <: signal;
                    workerChanBR <: signal;
                    c_out        <: signal;
                    toVisualiser <: signal;
                    return;
                    break;
                }
                break;

            default :
                    //sends signal to workers so the know what to expect
                    // 0=act as normal, -1=get ready to export, -2= shutdown
                    workerChanTL <: signal;
                    workerChanTR <: signal;
                    workerChanBL <: signal;
                    workerChanBR <: signal;
                    uchar temp;

                    if(signal==-1) {
                        //when signal is -1 the distributor gets ready to export
                        c_out <: signal;
                        for (int j = 0; j < IMWD; j++) {
                            for (int i = 0; i < IMHT; i++) {
                                //it reads in values for each value in the matrix,
                                if ((i<(IMWD/2)) && (j<(IMHT/2))) {
                                    //if in the top left square recieve from workerTL
                                    workerChanTL :> temp;
                                }
                                else if ((i>=(IMWD/2)) && (j<(IMHT/2))) {
                                    //if in the top right square recieve from workerTR
                                    workerChanTR :> temp;
                                }
                                else if ((i<(IMWD/2)) && (j>=(IMHT/2))) {
                                    //if worker is in the Bottom left corner recieve from workerBL
                                    workerChanBL :> temp;
                                }
                                else if ((i>=(IMWD/2)) && (j>=(IMHT/2))) {
                                    //if in the Bottom right square recieve from workerBR
                                    workerChanBR :> temp;
                                }
                                c_out <: (uchar)( temp); // send value to dataOut
                                //printf("%-4.1d",temp);
                             }
                             //printf("\n");
                        }

                        signal=0;//set signal to normal
                    }


                    //channel waits to recieve the edges of each square of the matrix
                    for (int i = 0; i < IMHT/2; i++) {

                        workerChanTL :> TLright[i];
                        workerChanTL :> TLbottom[i];
                        workerChanTR :> TRleft[i];
                        workerChanTR :> TRbottom[i];
                        workerChanBL :> BLright[i];
                        workerChanBL :> BLtop[i];
                        workerChanBR :> BRleft[i];
                        workerChanBR :> BRtop[i];

                    }

                    //channel waits to receive the corners of each square of the matrix
                    workerChanTL :> TLcorner;
                    workerChanTR :> TRcorner;
                    workerChanBL :> BLcorner;
                    workerChanBR :> BRcorner;

                    //channel passes back the edges it has received to the cores that require it
                    for (int i = 0; i < IMHT/2; i++) {
                        workerChanTL <: TRleft[i];
                        workerChanTL <: BLtop[i];
                        workerChanTR <: TLright[i];
                        workerChanTR <: BRtop[i];
                        workerChanBL <: TLbottom[i];
                        workerChanBL <: BRleft[i];
                        workerChanBR <: BLright[i];
                        workerChanBR <: TRbottom[i];

                    }

                    //channel passes back the corners it has received to the cores that require it
                    workerChanTL <: BRcorner;
                    workerChanTR <: BLcorner;
                    workerChanBL <: TRcorner;
                    workerChanBR <: TLcorner;

                    //distributor adds up the live cells from each worker;
                    noOfLiveCells=0;
                    workerChanTL :> live;
                    noOfLiveCells+=live;
                    workerChanTR :> live;
                    noOfLiveCells+=live;
                    workerChanBL :> live;
                    noOfLiveCells+=live;
                    workerChanBR :> live;
                    noOfLiveCells+=live;
                    //sends the no of live cells to the visualiser
                    toVisualiser<:noOfLiveCells;
                    turn++;
                    //printf("turn %d",turn);
                    //printf("\n");
                    break;

         }
     }
}


/////////////////////////////////////////////////////////////////////////////////////////
//
// worker threads
//
/////////////////////////////////////////////////////////////////////////////////////////

void workerTopLeft(chanend workerChanTL)
{

    //storage for the matrix and the edges/corners which need to be communicated
    uchar matrix[IMHT/2][IMWD/2];
    uchar tempMatrix[IMHT/2][2];
    uchar TRleft[IMHT/2];
    uchar BLtop[IMHT/2];
    uchar BRcorner;
    int noOfLiveCells=0;

    //the initial matrix is set up
    for (int i = 0; i < IMHT/2; i++) {
        for (int j = 0; j < IMHT/2; j++) {
            workerChanTL :> matrix[j][i];
            if(matrix[j][i]==0xFF){
                noOfLiveCells++;
            }
        }
    }

    while(1){

        int signal;
        workerChanTL :> signal;
        if(signal == -2){
            return;
        }
        //if the export button has been pressed, the current matrix is sent back to distributor
        if (signal == -1) {
            for (int i = 0; i < IMHT/2; i++) {
                for (int j = 0; j < IMHT/2; j++) {
                    workerChanTL <: matrix[j][i];
                }
            }

        }

        //the edges of this matrix are sent back to the distributor
        for (int i = 0; i < IMHT/2; i++) {
            workerChanTL <: matrix[(IMHT/2)-1][i];
            workerChanTL <: matrix[i][(IMHT/2)-1];
        }
        //the corner of the matrix is sent back to the distributor
        workerChanTL <: matrix[(IMHT/2)-1][(IMHT/2)-1];

        //the edges of the adjacent matrices are read in from the distributor
        for (int i = 0; i < IMHT/2; i++) {
            workerChanTL :> TRleft[i];
            workerChanTL :> BLtop[i];
        }
        //the corner of the diagonal matrix is read in from the distributor
        workerChanTL :> BRcorner;


        int neighbours = 0;

        for(int y = 0; y < IMHT/2; y++ )
        {
            for( int x = 0; x < IMWD/2; x++ )
            {
                neighbours = 0;
                //gets the number of neighbours for this cell
                for (int i = y-1; i < y+2; i++) {

                    for (int j = x-1; j < x+2; j++) {

                        //gets the neighbours which are in it's own square matrix
                        if (((i>=0)&&(i<IMWD/2)) && ((j>=0)&&(j<IMHT/2))) {

                            if ( (matrix[j][i]==0xFF) && !((i==y)&&(j==x)) ) {
                                neighbours++;
                            }


                        //gets the neighbours which are in the adjacent edges/corners
                        } else if((j==IMWD/2) && (i>0)) {

                            if (i==IMHT/2) {
                                if (BRcorner==0xFF) {
                                    neighbours++;
                                }
                            } else if (TRleft[i]==0xFF){
                                neighbours++;
                            }

                        } else if ((i==IMHT/2) && (j>0)) {

                            if (BLtop[j]==0xFF) {
                                neighbours++;
                            }
                        }

                    }
                }
                //printf("%d", neighbours);

                //rules of the game are implemented
                if (matrix[x][y] == 0xFF) { //rules for live cells

                     if((neighbours<2)||(neighbours>3)) {
                         tempMatrix[x][1] = 0; //live cells without 2-3 neighbours die
                         noOfLiveCells--;
                     } else {
                         tempMatrix[x][1] = 0xFF; //otherwise they stay alive
                     }

                } else { //rules for dead cells

                     if (neighbours==3) { //dead cells with 3 neighbours become alive
                         tempMatrix[x][1] = 0xFF;
                         noOfLiveCells++;
                     } else{
                         tempMatrix[x][1] = 0; //otherwise they stay dead
                     }

                }
            }

            for(int i=0;i<IMHT/2;i++){
                if(y>0){
                    //move top row of the temp matrix into the matrix now that row is no longer needed to be referenced
                    matrix[i][y-1]=tempMatrix[i][0];
                }
                //move the second temp row ot the top temp row
                tempMatrix[i][0]=tempMatrix[i][1];
                if(y==((IMHT/2)-1)){
                    // if the matrix is now fully completed, then move the top temp row into the final row of the matrix
                  matrix[i][y] = tempMatrix[i][0];
                }
            }
        }

        //worker sends number of live cells to distributor;
        workerChanTL<:noOfLiveCells;

    }
}

void workerTopRight(chanend workerChanTR)
{

    //storage for the matrix and the edges/corner which are sent to it
    int turn=0;
    uchar matrix[IMHT/2][IMWD/2];
    uchar tempMatrix[IMHT/2][2];
    uchar TLright[IMHT/2];
    uchar BRtop[IMHT/2];
    uchar BLcorner;
    int noOfLiveCells=0;

    //the initial matrix is set up
    for (int i = 0; i < IMHT/2; i++) {
            for (int j = 0; j < IMHT/2; j++) {
                workerChanTR :> matrix[j][i];
                if(matrix[j][i]==0xFF){
                    noOfLiveCells++;
                }
            }
    }

    while(1){
        turn++;
        int signal;
        workerChanTR :> signal;
        if(signal==-2){
            return;
        }
        //if the export button has been pressed, the current matrix is sent back to distributor
        if (signal == -1) {

            for (int i = 0; i < IMHT/2; i++) {

                for (int j = 0; j < IMHT/2; j++) {
                    workerChanTR <: matrix[j][i];
                }
            }

        }

        //the edges of this matrix are sent back to the distributor
        for (int i = 0; i < IMHT/2; i++) {
                workerChanTR <: matrix[0][i];
                workerChanTR <: matrix[(IMHT/2)-1][i];
        }
        //the corner of this matrix is sent back to the distributor
        workerChanTR <: matrix[0][(IMHT/2)-1];

        //the edges of the adjacent matrices are read in from the distributor
        for (int i = 0; i < IMHT/2; i++) {
            workerChanTR :> TLright[i];
            workerChanTR :> BRtop[i];
        }
        //the corner of the diagonal matrices is read in from the distributor
        workerChanTR :> BLcorner;


        int neighbours = 0;

            for(int y = 0; y < IMHT/2; y++ )
            {
                for( int x = 0; x < IMWD/2; x++ )
                {
                    neighbours = 0;
                    //gets the number of neighbours for this cell
                    for (int i = y-1; i < y+2; i++) {

                        for (int j = x-1; j < x+2; j++) {

                            //gets the neighbours which are in it's own square matrix
                            if (((i>=0)&&(i<IMWD/2)) && ((j>=0)&&(j<IMHT/2))) {

                                if ( (matrix[j][i]==0xFF) && !((i==y)&&(j==x)) ) {
                                    neighbours++;
                                }

                            //gets the neighbours which are in the adjacent edges/corners
                            } else if((j==-1) && (i>0)) {

                                if (i==IMHT/2) {

                                    if (BLcorner==0xFF) {
                                        neighbours++;

                                    }

                                } else if (TLright[i]==0xFF){
                                    neighbours++;
                                }
                            } else if ((i==IMHT/2) && (j<IMHT/2)) {

                                if (BRtop[j]==0xFF) {
                                    neighbours++;
                                }

                            }
                        }
                    }
                    //printf("%d", neighbours);
                    //rules of the game are implemented
                    if (matrix[x][y] == 0xFF) { //rules for live cells

                         if((neighbours<2)||(neighbours>3)) {

                             tempMatrix[x][1] = 0; //live cells without 2-3 neighbours die
                             noOfLiveCells--;

                         } else {
                             tempMatrix[x][1] = 0xFF; //otherwise they stay alive
                         }

                    } else { //rules for dead cells

                         if (neighbours==3) { //dead cells with 3 neighbours become alive
                             tempMatrix[x][1] = 0xFF;
                             noOfLiveCells++;
                         } else{
                             tempMatrix[x][1] = 0; //otherwise they stay dead
                         }

                    }

                }
                for(int i=0;i<IMHT/2;i++){
                    if(y>0){
                        matrix[i][y-1]=tempMatrix[i][0];
                    }
                    tempMatrix[i][0]=tempMatrix[i][1];
                    if(y==((IMHT/2)-1)){
                      matrix[i][y] = tempMatrix[i][0];
                    }
                }

            }

            workerChanTR<:noOfLiveCells;
      }
}

void workerBottomLeft(chanend workerChanBL)
{
    //storage for the matrix and the edges/corners which need to be communicated
    uchar tempMatrix[(IMHT/2)][2];
    uchar matrix[IMHT/2][IMWD/2];
    uchar TLbottom[IMHT/2];
    uchar BRleft[IMHT/2];
    uchar TRcorner;
    int noOfLiveCells=0;

    //the initial matrix is set up
    for (int i = 0; i < IMHT/2; i++) {
            for (int j = 0; j < IMHT/2; j++) {
                workerChanBL :> matrix[j][i];
                if(matrix[j][i]==0xFF){
                    noOfLiveCells++;
                }
            }
        }

    while(1){

        int signal;
        workerChanBL :> signal;
        if(signal==-2){
            return;
        }

        //if the export button has been pressed, the current matrix is sent back to distributor
        if (signal == -1) {
            for (int i = 0; i < IMHT/2; i++) {
                for (int j = 0; j < IMHT/2; j++) {
                    workerChanBL <: matrix[j][i];
                }
            }

        }

        //the edges of this matrix are sent back to the distributor
        for (int i = 0; i < IMHT/2; i++) {
            workerChanBL <: matrix[(IMHT/2)-1][i];
            workerChanBL <: matrix[i][0];
        }
        //the corner of this matrix is sent back to the distributor
        workerChanBL <: matrix[(IMHT/2)-1][0];

        //the edges of the adjacent matrices are read in from the distributor
        for (int i = 0; i < IMHT/2; i++) {
            workerChanBL :> TLbottom[i];
            workerChanBL :> BRleft[i];
        }
        //the corner of the diagonal matrix is read in from the distributor
        workerChanBL :> TRcorner;

        int neighbours = 0;

            for(int y = 0; y < IMHT/2; y++ )
            {
                for( int x = 0; x < IMWD/2; x++ )
                {
                    neighbours = 0;
                    //gets the number of neighbours for this cell
                    for (int i = y-1; i < y+2; i++) {
                        for (int j = x-1; j < x+2; j++) {

                            //gets the neighbours which are in it's own square matrix
                            if (((i>=0)&&(i<IMWD/2)) && ((j>=0)&&(j<IMHT/2))) {
                                if ( (matrix[j][i]==0xFF) && !((i==y)&&(j==x)) ) {
                                    neighbours++;
                                }

                            //gets the neighbours which are in the adjacent edges/corners
                            } else if((j==(IMWD/2)) && (i<(IMWD/2))) {
                                if (i==-1) {
                                    if (TRcorner==0xFF) {
                                        neighbours++;
                                    }
                                } else if (BRleft[i]==0xFF){
                                    neighbours++;
                                }
                            } else if ((i==-1) && (j>0)) {
                                if (TLbottom[j]==0xFF) {
                                    neighbours++;
                                }
                            }

                        }
                    }
                    //printf("%d", neighbours);

                    //rules of the game are implemented
                    if (matrix[x][y] == 0xFF) { //rules for live cells

                         if((neighbours<2)||(neighbours>3)) {
                             tempMatrix[x][1] = 0; //live cells without 2-3 neighbours die
                             noOfLiveCells--;
                         } else {
                             tempMatrix[x][1] = 0xFF; //otherwise they stay alive
                         }

                    } else { //rules for dead cells

                         if (neighbours==3) { //dead cells with 3 neighbours become alive
                             tempMatrix[x][1] = 0xFF;
                             noOfLiveCells++;
                         } else{
                             tempMatrix[x][1] = 0; //otherwise they stay dead
                         }

                    }

                }
                for(int i=0;i<IMHT/2;i++){
                    if(y>0){
                        matrix[i][y-1]=tempMatrix[i][0];
                    }
                    tempMatrix[i][0]=tempMatrix[i][1];
                    if(y==((IMHT/2)-1)){
                      matrix[i][y] = tempMatrix[i][0];
                    }
                }
            }
            workerChanBL<:noOfLiveCells;

    }

}

void workerBottomRight(chanend workerChanBR)
{

    //storage for the matrix and the edges/corners which need to be communicated
    uchar matrix[IMHT/2][IMWD/2];
    uchar tempMatrix[(IMHT/2)][2];
    uchar BLright[IMHT/2];
    uchar TRbottom[IMHT/2];
    uchar TLcorner;
    int noOfLiveCells=0;

    //the initial matrix is set up
    for (int i = 0; i < IMHT/2; i++) {
            for (int j = 0; j < IMHT/2; j++) {
                workerChanBR :> matrix[j][i];
                if(matrix[j][i]==0xFF){
                    noOfLiveCells++;
                }
            }
        }

    while(1){

        int signal;
        workerChanBR :> signal;
        if(signal==-2){
            return;
        }

        //if the export button has been pressed, the current matrix is sent back to distributor
        if (signal == -1) {
            for (int i = 0; i < IMHT/2; i++) {
                for (int j = 0; j < IMHT/2; j++) {
                    workerChanBR <: matrix[j][i];
                }
            }

        }

        //the edges of this matrix are sent back to the distributor
        for (int i = 0; i < IMHT/2; i++) {
            workerChanBR <: matrix[0][i];
            workerChanBR <: matrix[i][0];
        }
        //the corner of this matrix is sent back to the distributor
        workerChanBR <: matrix[0][0];

        //the edges of the adjacent matrices are read in from the distributor
        for (int i = 0; i < IMHT/2; i++) {
            workerChanBR :> BLright[i];
            workerChanBR :> TRbottom[i];
        }
        //the corner of the diagonal matrix is read in from the distributor
        workerChanBR :> TLcorner;

        int neighbours = 0;


           for(int y = 0; y < IMHT/2; y++ )
           {
              for( int x = 0; x < IMWD/2; x++ )
              {
                        neighbours = 0;
                        //gets the number of neighbours for this cell
                        for (int i = y-1; i < y+2; i++) {
                            for (int j = x-1; j < x+2; j++) {

                                //gets the neighbours which are in it's own square matrix
                                if (((i>=0)&&(i<IMWD/2)) && ((j>=0)&&(j<IMHT/2))) {
                                    if ( (matrix[j][i]==0xFF) && !((i==y)&&(j==x)) ) {
                                        neighbours++;
                                    }

                                //gets the neighbours which are in the adjacent edges/corners
                                } else if((j==-1) && (i<(IMWD/2))) {
                                    if (i==-1) {
                                        if (TLcorner==0xFF) {
                                            neighbours++;
                                        }
                                    } else if (BLright[i]==0xFF){
                                        neighbours++;
                                    }
                                } else if ((i==-1) && (j<(IMWD/2))) {
                                    if (TRbottom[j]==0xFF) {
                                        neighbours++;
                                    }
                                }

                            }
                        }
                        //printf("%d", neighbours);

                        //rules of the game are implemented
                        if (matrix[x][y] == 0xFF) { //rules for live cells

                             if((neighbours<2)||(neighbours>3)) {
                                 tempMatrix[x][1] = 0; //live cells without 2-3 neighbours die
                                 noOfLiveCells--;
                             } else {
                                 tempMatrix[x][1] = 0xFF; //otherwise they stay alive
                             }

                        } else { //rules for dead cells

                             if (neighbours==3) { //dead cells with 3 neighbours become alive
                                 tempMatrix[x][1] = 0xFF;
                                 noOfLiveCells++;
                             } else{
                                 tempMatrix[x][1] = 0; //otherwise they stay dead
                             }

                        }

                    }
              for(int i=0;i<IMHT/2;i++){
                  if(y>0){
                      matrix[i][y-1]=tempMatrix[i][0];
                  }
                  tempMatrix[i][0]=tempMatrix[i][1];
                  if(y==((IMHT/2)-1)){
                    matrix[i][y] = tempMatrix[i][0];
                  }
              }
           }
           workerChanBR<:noOfLiveCells;
           //copy the new matrix to the old one

    }
}



/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to pgm image file
//
/////////////////////////////////////////////////////////////////////////////////////////

void DataOutStream( chanend c_in)
{
  char outfname[] = "testout.pgm"; //put your output image path here, absolute path
  int res;
  uchar line[ IMWD ];
  printf( "DataOutStream:Start...\n" );
  int signal;
  while(1){
      c_in :> signal;
      if(signal==-2){
          return;
      }
      res = _openoutpgm( outfname, IMWD, IMHT );
      if( res )
      {
        //printf( "DataOutStream:Error opening %s\n.", outfname );
        return;
      }
      for( int y = 0; y < IMHT; y++ )
      {
        for( int x = 0; x < IMWD; x++ )
        {
          c_in :> line[ x ];
          //printf( "-%4.1d ", line[ x ] ); //uncomment to show image values
        }
         //printf( "\n" ); //uncomment to show image values
        _writeoutline( line, IMWD );
      }
      printf("done");
      _closeoutpgm();
  }

  printf( "DataOutStream:Done...\n" );
  return;
}



//MAIN PROCESS defining channels, orchestrating and starting the threads
int main()
{

  chan c_inIO, c_outIO, buttonsToDistributor, workerChanTL, workerChanTR, workerChanBR, workerChanBL, toVisualiser,quadrant0, quadrant1, quadrant2, quadrant3;

  par
  {
    on stdcore[0] : visualiser( toVisualiser, quadrant0, quadrant1, quadrant2, quadrant3);
    on stdcore[0] : buttonListener(buttons, buttonsToDistributor);
    on stdcore[0] : DataInStream(c_inIO );
    on stdcore[0] : distributor( toVisualiser,c_inIO, c_outIO, buttonsToDistributor, workerChanTL, workerChanTR, workerChanBL, workerChanBR );
    on stdcore[3] : workerTopLeft(workerChanTL);
    on stdcore[1] : workerTopRight(workerChanTR);
    on stdcore[2] : workerBottomLeft(workerChanBL);
    on stdcore[3] : workerBottomRight(workerChanBR);
    on stdcore[2] : DataOutStream( c_outIO );
    on stdcore[0]: showLED(cled0,quadrant0);
    on stdcore[1]: showLED(cled1,quadrant1);
    on stdcore[2]: showLED(cled2,quadrant2);
    on stdcore[3]: showLED(cled3,quadrant3);

  }

  return 0;
}
