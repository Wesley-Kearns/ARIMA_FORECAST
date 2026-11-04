/* Program - "READRPM.SAS"

Converted from READSMC.SAS template
Data source: RPM.csv (monthly RPM series, Jan 2000 - May 2026)

University of Kentucky */


/* Read raw data into a permanent SAS file */
data sasuser.RPM;
  format DATE MONYY.;
  DATE=intnx('MONTH','1DEC99'D, _N_); 
  input RPM;

  label 
  RPM =	"Monthly RPM";
 
  cards;  
48263245
48580127
59632014
57636732
59749900
64046964
66435577
65252958
55470176
57979416
55302968
54460418
52049391
48845243
60769073
58479185
59190930
63729974
67144380
67664023
38207236
43609263
44598156
47422033
45699949
43964813
56037382
51993221
54695480
59031826
61965515
62332762
48731119
53268604
49186629
55458015
49830903
45514803
54994261
50304173
53070727
58958204
64470622
63540849
51022359
55549640
52785625
57280778
52332277
51347537
61923381
60744714
61384009
67430529
71593504
69244299
56494925
61743819
58329543
61424449
57936503
54233804
68725711
63817097
67072652
71621917
76041550
72415556
60791372
62624694
60533679
63220661
59828980
55491266
69483900
67122793
68435521
73147256
76711219
73076758
61249897
65091487
62637778
65157505
61896193
56914815
71497177
68813909
70947617
75914661
79865223
78314560
64781658
68397379
65333114
66764862
63504217
60578995
73427185
67956166
71791924
75301714
78772769
76359814
60292068
64011438
57684017
62697156
57424037
52712775
65147741
64352894
65015083
70562995
76201891
73607921
60512481
63325757
58170882
62377082
58655574
52438942
67304853
64062751
67970934
73591283
78192819
75714090
64494149
68199554
62471217
64946702
60720980
54492725
69104312
66733086
70797151
75121815
80361588
76193082
65499304
67300832
62528875
65500668
61076689
57448037
70799480
67807033
71155609
76014162
79640786
77738861
65230938
66974008
63372211
65923928
62433674
57526656
72164048
67827983
72981718
77865105
81268540
79332043
66575979
69054445
63029552
70372528
64075229
57888205
73637965
70715384
75191291
79468784
83675271
81231837
68392098
71270226
65178503
71781111
65975447
59784666
75751609
73090871
78002935
82695216
88263768
85234949
72483190
76094668
70030247
74827186
69265865
64559135
78684812
75127770
80784690
86518457
90628483
86136355
75323792
77274227
72215277
76957615
71433297
64261254
80838984
79494360
83542041
89667877
94106754
90444528
74645832
80629312
75655182
79629124
73352756
68213441
85599897
82536712
88019738
94375329
98883723
94835592
79102243
84374600
79461417
82764474
76935981
70762598
90028517
86209795
92550535
97811522
101794185
98025331
83345979
87646447
80521747
89959899
81045830
73892439
42770844
2908236
8597006
14904888
22062675
23818082
23073723
27870756
27957384
30832402
27800391
26323206
42683735
47644846
57822304
68542276
78048249
71745477
60555482
66925246
67951401
71880335
56461934
58039691
77898310
78810921
83505662
87633371
92091492
87932991
80340630
84128759
78902163
82339322
76670407
71601173
89581512
88145675
93560839
98688403
103663185
97888687
87867782
93097143
86496249
90668486
81030970
78689870
96770546
92096423
99370931
105399318
108410637
101891697
89211873
93747088
86241811
96535007
83020018
76340684
96511478
93562863
98997224
105259313
109835239
103422634
89319937
96268591
86170252
96161676
83220828
78642748
99003685
93984347
99440769
run;


/* Print the data */
proc print data=sasuser.RPM;
run;


/* Summarize the data */
proc summary data=sasuser.RPM print;
  var RPM;
run;


/* Plot the time series */
proc gplot data=sasuser.RPM;
  symbol height=.3 value=dot width=1 color=red interpol=join; 
  title1 "RPM PER MONTH";
  plot RPM*DATE / frame;
run;

quit;

/*==================================================================
  RPM ARIMA - improved version
  Main changes are marked [1]-[8] and match the notes in chat.
  NOTE: The COVID dummy dates are a starting template. Replace them
        with the dates and types (AO / LS) your OUTLIER output reports.
==================================================================*/

proc options option=macro; run;

TITLE1 "LOG TEST FOR RPM";
/* [1] ar=13 covers a full seasonal cycle for monthly data (ar=5 does not) */
%logtest(sasuser.RPM, RPM, print=yes, ar=13);
%logtest(sasuser.RPM, RPM, print=yes, ar=13, dif=(1));


/*------------------------------------------------------------------
  [2] Add 12 future months so the intervention dummies have values
      over the forecast horizon (PROC ARIMA needs them for input=)
------------------------------------------------------------------*/
data FUTURE;
   set sasuser.rpm end=last;
   if last then do;
      do i = 1 to 12;
         DATE = intnx('month', DATE, 1, 'b');
         RPM  = .;
         output;
      end;
   end;
   keep DATE RPM;
run;

data RPMTEMP;
   set sasuser.rpm FUTURE;
   lnRPM = log(RPM);

   /* [3] COVID intervention variables (edit to match OUTLIER output) */
   AO_MAR20 = (DATE = '01MAR2020'd);   /* one-month additive outlier       */
   COVID_P  = (DATE = '01APR2020'd);   /* pulse; given a decaying response */
                                       /* below = crash, then recovery     */
   format DATE monyy7.;
run;


TITLE "ARIMA ESTIMATES FOR MONTHLY DATA";
proc arima data=RPMTEMP plots=(residual(all) forecast(forecast));

   /* [4] Unit-root checks: regular ADF with several lags, then a
          seasonal (lag-12) Dickey-Fuller test                      */
   identify var=lnRPM(1)  nlag=36 stationarity=(adf=(0,1,2,3,4));
   identify var=lnRPM(1)  nlag=36 stationarity=(adf=(0,1,2) dlag=12);

   /* [5] Seasonal + regular differencing, with interventions as
          inputs. MINIC/SCAN suggest orders for the non-seasonal part. */
   identify var=lnRPM(1,12) nlag=36
            crosscorr=(AO_MAR20(1,12) COVID_P(1,12))
            minic scan p=(0:4) q=(0:4) noprint;

   /* [6] Start from the "airline model" (0,1,1)(0,1,1)12 plus the
          interventions. "/ (1) COVID_P" = sudden drop that decays
          geometrically (delta should land between 0 and 1).
          Compare AIC/SBC and Ljung-Box results against alternatives,
          e.g. p=(1)(12) q=(1)(12), or your original p=(6 12) q=(2).  */
   estimate q=(1)(12)
            input=( AO_MAR20  / (1) COVID_P )
            noint method=ml;

   /* Re-check: anything still flagged needs a dummy added above */
   outlier maxnum=10 alpha=0.01;

   forecast lead=12 interval=month id=DATE out=OUTFRPM alpha=.10;
run;
quit;


/*------------------------------------------------------------------
  [7] Back-transform with log bias correction.
      exp(forecast) is the MEDIAN; adding 0.5*STD^2 gives the MEAN.
      Interval bounds are just exponentiated (no correction).
------------------------------------------------------------------*/
data RPMTEMP2;
   set OUTFRPM;
   where DATE > '15DEC2018'd;           /* 4-digit year avoids YEARCUTOFF issues */
   FORECAST = exp(FORECAST + 0.5*STD**2);
   U90      = exp(U90);
   L90      = exp(L90);
   RPM      = exp(lnRPM);
   if DATE < '01JUN2026'd then do;
      FORECAST = .; U90 = .; L90 = .;
   end;
run;

proc print data=RPMTEMP2;
   TITLE "FORECASTS FOR RPM";
run;


/* [8] SGPLOT replaces SYMBOL/GPLOT and shades the 90% interval */
proc sgplot data=RPMTEMP2;
   TITLE "ARIMA FORECASTS FOR RPM";
   band   x=DATE lower=L90 upper=U90 / transparency=0.6
          fillattrs=(color=lightblue) legendlabel="90% interval";
   series x=DATE y=RPM      / markers lineattrs=(color=green) legendlabel="Actual";
   series x=DATE y=FORECAST / lineattrs=(color=red thickness=2) legendlabel="Forecast";
   refline '01JUN2026'd / axis=x lineattrs=(pattern=dash);
run;


/*------------------------------------------------------------------
  OPTIONAL: true out-of-sample check. Re-estimate on data through
  Jun 2025, forecast Jul 2025 - Jun 2026, and compare with actuals
  (MAPE / RMSE). Do this for each candidate model and pick the winner.
------------------------------------------------------------------*/
data HOLDOUT;
   set RPMTEMP;
   if DATE >= '01JUL2025'd then lnRPM = .;
run;

proc arima data=HOLDOUT;
   identify var=lnRPM(1,12) crosscorr=(AO_MAR20(1,12) COVID_P(1,12)) noprint;
   estimate q=(1)(12) input=( AO_MAR20 / (1) COVID_P ) noint method=ml noprint;
   forecast lead=12 interval=month id=DATE out=OUTHOLD noprint;
run;
quit;

data ACCURACY;
   merge OUTHOLD(keep=DATE FORECAST STD) RPMTEMP(keep=DATE RPM);
   by DATE;
   where '01JUL2025'd <= DATE <= '01JUN2026'd;
   FCST   = exp(FORECAST + 0.5*STD**2);
   APE    = abs(RPM - FCST) / RPM * 100;
   SQERR  = (RPM - FCST)**2;
run;

proc sql;
   select mean(APE) as MAPE format=8.2,
          sqrt(mean(SQERR)) as RMSE
   from ACCURACY;
quit;
