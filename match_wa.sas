/* dummy data sets study and control
variables:
id study age lwt race smoke ptd ht ui
1 	0 	14 	135 	1 	0 	0 	0 	0
104 0 	17 	130 	3 	1 	1 	0 	1
*/

* macro call: match(case=_Case, control=_Control, ratio=1,
						matchVars=age:1|race|lwt:5, out=_matched);
* create the ranges - age:1|race|lwt:5;

%macro match(case=,control=,ratio=1,matchVars=,out=test);
	* count the number of match variables;
	%let numvars=%sysfunc(countc(&matchVars.,'|'))+1;
	%put There are %eval(&numvars.) match variables;
	
	* create the syntax to manage all the conditions;
	* loop through the number of variables;
	%do j=1 %to &numvars.;
		* put the variable and range into macro vars;
		%let mv=%scan(&matchVars.,&j.,|);
		%let var=%scan(&mv.,1,:);
		%let range=%scan(&mv.,2,:);
		* start setting up the string expressions for the sql join;
		%if (&range.~=) %then %do;
	  		data &control.;				* add "range" columns to the control table;
	    		set &control.;
				&var._L=&var.-&range.;	* +- conditions on the range;
				&var._H=&var.+&range.;
	  		run;
	  		%let cond=(&case..&var. between &control..&var._L and &control..&var._H);
		%end;
		%else %do;
	  		%let cond=(&case..&var.=&control..&var.);
		%end;

		* put the variables in the select statement;
		%let newVar=%str(&case..&var. as case_&Var., &control..&var. as ctrl_&Var.);

		%if (&j.=1) %then %do;
	  		%let conditions=&cond.;
	  		%let newVars=%str(&newVar.);
		%end;
		%else %do;
	  		%let conditions=&conditions. and &cond.;
	  		%let newVars=&newVars.,&newVar.;
		%end;
	%end;
	%put &conditions.;
	%put &newvars.;

	* now match case and control tables using the criteria;
	proc sql;
	create table &out. as
		select a.ID as caseID 
			  ,b.ID as controlID
			  ,&newVars.
		from &case. as a,
			 &control. as b
		where (&conditions.)
		order by caseID;
	quit;

	data &out.;
	set &out.;
	rnd=ranuni(1); *generate a random number;
	run;

	proc sql;
	create table &out. as
		select &out..*, n(caseID) as count from &out. group by caseID;
	quit;

	proc sort data=&out.;
	by controlID count rnd;
	run;

	data &out.;
	set &out.;
	by controlID;
	if first.controlID then output; *Only pick the first controlID;
	run;

	proc sort data=&out.;
	by caseID rnd;
	run;

	data &out.(drop=k count rnd);
	set &out.;
	by caseID;
	retain k;
	if first.caseID then k=0;
	k+1;
	if k<=&ratio. then output;
	run;

	* grab the cases that had no matches;
	data &case._unmatched;
	merge &case.(in=a rename=(id=caseID)) &out.(in=b);
	by caseID;
	if b=0 and a=1;
	run;

%mend match;


%match(case=study, control=control, ratio=1, matchVars=age:1|race|lwt:5, out=matched);

