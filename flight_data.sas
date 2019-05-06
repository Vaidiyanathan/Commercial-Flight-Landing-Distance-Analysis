/*1*/
/*combine datasets faa1 and faa2*/
FILENAME REFFILE '/folders/myfolders/SC/flight_data/FAA1.xls';

PROC IMPORT DATAFILE=REFFILE DBMS=XLS OUT=SC.flight_data_faa1;
GETNAMES=YES;
RUN;

FILENAME REFFILE '/folders/myfolders/SC/flight_data/FAA2.xls';

PROC IMPORT DATAFILE=REFFILE DBMS=XLS OUT=SC.flight_data_faa2;
GETNAMES=YES;
RUN;

data flight_data_combined;
set sc.flight_data_faa1 sc.flight_data_faa2;
run;

/*remove empty observations*/
data want;
set flight_data_combined;
if compress(cats(of _all_), '.')=' ' then delete;
run;

/*print first 15 observations of the total flight data*/
proc print data=flight_data_combined(obs=15);
run;

/*2*/
/*Completeness check of each variable - examine if missing values are present*/
proc means data=want n nmiss;
run;

/*3*/
/*observations with abnormal durations*/
data f_duration_abnormal;
set want;
where duration < 40;
run;

proc means data=f_duration_abnormal n;
var duration;
run;

/*observations with abnormal SPEED_GROUND*/
data f_speed_ground_abnormal;
set want;
where speed_ground < 30 or speed_ground > 140;
run;

proc means data=f_speed_ground_abnormal n;
var speed_ground;
run;

/*observations with abnormal SPEED_air*/
data f_speed_air_abnormal;
set want;
where speed_air < 30 or speed_air > 140;
run;

proc means data=f_speed_air_abnormal n;
var speed_air;
run;

/*observations with abnormal height*/
data f_height_abnormal;
set want;
where height < 6;
run;

proc means data=f_height_abnormal n;
var height;
run;

/*observations with abnormal distance*/
data f_distance_abnormal;
set want;
where distance >=6000;
run;

proc means data=f_distance_abnormal n;
var distance;
run;

/*4*/
/* LABELING ABNORMAL DURATIONS*/

data f_labeled;
set want;
if (duration ^=. and duration < 40) or (speed_ground ^=. and (speed_ground > 140 or speed_ground < 30)) or (speed_air ^=. and (speed_air >140 or speed_air < 30)) or (height < 6 and height ^= .) or (distance >=6000 and distance ^= .) then landing =0;
else landing =1;
run;
proc means data=f_labeled n nmiss;
run;
/*finding abnormal values*/
data f_c;
set f_labeled;
where landing = 0;
run;
proc means data=f_c n nmiss;
run;

/*removing obs with abnormal values, since it is relatively small to the data*/
data f_c;
set f_labeled;
where landing = 1;
run;
proc means data=f_c n nmiss;
run;

/*removing exact duplicates*/
proc sort data=f_c out=f_clean nodupkey;
by aircraft no_pasg speed_ground speed_air height pitch distance;
run;
/*
Common unit for numeric variables - time in hour, distance in km and speed in kmph

data f_labeled;
set f_lab;
distance_km = distance/3280.84;
duration_hour = duration/60;
speed_ground_kmph = speed_ground * 1.609344;
speed_air_kmph = speed_air*1.609344;
height_km = height/1000;
keep aircraft duration_hour no_pasg speed_ground_kmph speed_air_kmph height_km pitch distance_km landing;
run;

REORDER

data f_labeled;
retain aircraft duration_hour no_pasg speed_ground_kmph speed_air_kmph height_km pitch distance_km landing;
set f_labeled;
run;

proc print data=f_labeled(obs=15);
run;
*/

/*5*/
/*summarizing distribution of each variable*/
ods graphics / imagemap=on;

/* Exploring Data */
proc univariate data=WORK.f_clean;
	ods select Histogram;
	var duration no_pasg speed_ground speed_air height pitch distance;
	histogram duration no_pasg speed_ground speed_air height pitch distance / 
		normal;
	inset n mean median std max min q3 q1/ position=ne;
run;


/*exporting cleaned data to an excel*/
proc export data=f_clean
dbms = xls
outfile='/folders/myfolders/SC/flight_data/FAA_clean.xls'
replace;
run;

/*import clean data from excel*/
FILENAME REFFILE '/folders/myfolders/SC/flight_data/FAA_clean.xls';

PROC IMPORT DATAFILE=REFFILE DBMS=XLS OUT=work.flight_clean;
GETNAMES=YES;
RUN;

proc means data=flight_clean n nmiss mean median std min max q3 q1;
run;



%macro plot1(dataset, var1, var2);
proc plot data=&dataset;
plot &var1*&var2;
title "&var1 vs &var2 in &dataset";
run;
%mend plot1;

%plot1(flight_clean, distance, duration);
%plot1(flight_clean, distance, no_pasg);
%plot1(flight_clean, distance, speed_ground);
%plot1(flight_clean, distance, speed_air);
%plot1(flight_clean, distance, height);
%plot1(flight_clean, distance, pitch);
%plot1(flight_clean, speed_air, speed_ground);

/*
data abc;
set flight_clean;
array a1(*) duration no_pasg speed_ground speed_air height pitch distance;
array a2(*) duration no_pasg speed_ground speed_air height pitch distance;
	do i=1 to dim(a1);
	do j=1 to dim(a2);
%plot1(flight_clean, a1(i), a2(j));
output;
end;
end;
run;
*/

/*to check correlation among variables with respect to the landing distance*/
proc corr data=flight_clean;
var duration no_pasg speed_ground speed_air height pitch;
with distance;
title Correlation coefficients with Landing Distance;
run;
/*speed air, speed ground, pitch and height have p value less than 0.05*/

/*to check the correlation between primary varaibles which affect landing distance*/
proc corr data=flight_clean;
var speed_ground speed_air pitch height;
title Correlation coefficients btw air and grnd speed;
run;
/*here, we see that the speed air and speed_ground are correlated. hence it is a good practice to use only one of these. here we take speed air*/


proc reg data=flight_clean;
model distance = speed_ground height pitch/ r;
output out=diagnostics student=tt residual=residuals;
title Regression analysis of FAA dataset;
run;

proc ttest data = diagnostics;
var residuals;
run;

proc reg data=flight_clean;
model distance = speed_ground height pitch;
title Regression analysis of FAA dataset;
run;

proc print data= flight_clean(obs=15);
run;

/*Airbus*/
data airbus;
set flight_clean;
if aircraft = 'airbus';
run;


%plot1(airbus, distance, duration);
%plot1(airbus, distance, no_pasg);
%plot1(airbus, distance, speed_ground);
%plot1(airbus, distance, speed_air);
%plot1(airbus, distance, height);
%plot1(airbus, distance, pitch);
%plot1(airbus, speed_air, speed_ground);


proc corr data=airbus;
var duration no_pasg speed_ground speed_air height pitch;
with distance;
title Correlation coefficients with Landing Distance in Airbus;
run;

/*to check the correlation between primary varaibles which affect landing distance*/
proc corr data=airbus;
var speed_ground speed_air height;
title Correlation coefficients btw air and grnd speed;
run;

proc reg data=airbus;
model distance = speed_ground height;
title Regression analysis of FAA dataset airbus;
run;



/*Boeing*/
data boeing;
set flight_clean;
if aircraft = 'boeing';
run;

%plot1(boeing, distance, duration);
%plot1(boeing, distance, no_pasg);
%plot1(boeing, distance, speed_ground);
%plot1(boeing, distance, speed_air);
%plot1(boeing, distance, height);
%plot1(boeing, distance, pitch);
%plot1(boeing, speed_air, speed_ground);

proc corr data=boeing;
var duration no_pasg speed_ground speed_air height pitch;
with distance;
title Correlation coefficients with Landing Distance in boeing;
run;

/*to check the correlation between primary varaibles which affect landing distance*/
proc corr data=boeing;
var speed_ground speed_air;
title Correlation coefficients btw air and grnd speed;
run;

proc reg data=boeing;
model distance = speed_ground;
title Regression analysis of FAA dataset boeing;
run;
