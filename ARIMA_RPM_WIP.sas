proc options option=macro; run;

TITLE1 "LOG TEST FOR RPM" 
%logtest(sasuser.RPM, RPM, print=yes, ar=5);
%logtest(sasuser.RPM, RPM, print=yes, ar=5, dif=(1));

data RPMTEMP; 
	set sasuser.rpm;
	lnRPM= log(RPM);

run;

TITLE "ARIMA ESTIMATES FOR QUARTERLY DATA";
proc arima data = RPMTEMP;
	identify var=lnRPM(1,12) nlag=20 stationarity= (adf=(1)) ;
	estimate P=(1 2 18) Q=(0) method=ml plot; 
	forecast lead=12 interval=QUARTERLY id=DATE out=OUTFRPM alpha=.10; 
run; 

data RPMTEMP2;
	set OUTFRPM ;
	where DATE GT '15DEC18'D;
	FORECAST = exp(FORECAST);
	U90 = exp(U90);
	L90 = exp(L90);
	RPM = exp(lnRPM);
	IF DATE LT '01JUL26'D THEN DO;
		FORECAST = .; 
		U90= .; 
		L90= . ;
	END;
run;

proc print data=RPMTEMP2;
	TITLE "FORECASTS FOR RPM" ;
run;

/***  code to control graph appearance ***/
	SYMBOL1 I=JOIN V=DOT C=GREEN ;
	SYMBOL2 I=JOIN C=RED ;
	SYMBOL3 I=JOIN C=BLUE ;
	SYMBOL4 I=JOIN C=BLUE; 
/*****************************************/

proc gplot data= RPMTEMP2;
	TITLE "ARIMA FORECASTS FOR RPM";
	plot RPM*DATE=1  FORECAST*DATE=2 L90*DATE=3 U90*DATE=4 /overlay  
    HREF='01JUL26'D ;
run;

quit;
