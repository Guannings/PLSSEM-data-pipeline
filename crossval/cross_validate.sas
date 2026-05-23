/*****************************************************************
 * cross_validate.sas
 *
 * Independent cross-validation of the descriptives / reliability /
 * correlation / t-test / EFA layers using SAS native procedures.
 *
 * PLS-SEM itself is estimated in R ('seminr'); SAS has no equivalent
 * native PLS-SEM procedure (PROC CALIS does covariance-based SEM, a
 * different algorithm). This script therefore verifies the layers SAS
 * CAN reproduce. If the SAS numbers match the R / Python outputs to a
 * few decimals, the descriptives layer is confirmed by a third tool.
 *
 * Usage:
 *   1. Edit DATAPATH / OUTPATH below.
 *   2. Submit the whole script in SAS 9.4 / SAS Studio / Enterprise Guide.
 *   3. Compare the listing against the R / Python outputs.
 *****************************************************************/

* === CONFIGURATION (edit these two paths) ===========================;
%let DATAPATH = C:\path\to\synthetic_data;
%let OUTPATH  = C:\path\to\crossval_output;

libname xv "&OUTPATH";

* === STEP 1: import the cleaned CSVs =================================;
proc import datafile="&DATAPATH\survey_a_clean.csv"
            out=survey_a_raw dbms=csv replace;
    getnames=yes; guessingrows=max;
run;
proc import datafile="&DATAPATH\survey_b_clean.csv"
            out=survey_b_raw dbms=csv replace;
    getnames=yes; guessingrows=max;
run;

* === STEP 2: build the urban-stratification grouping ================;
* High-urbanization group = City=1, or City=2 with District in the
* selected high-urbanization district codes.;
%macro add_group(in=, out=);
    data &out;
        set &in;
        if City = 1 then group = 1;
        else if City = 2 and (District in (1, 2, 3, 4, 5, 18)) then group = 1;
        else group = 2;
        AT_score  = mean(of AT1-AT12);
        SN_score  = mean(of SN1-SN12);
        PBC_score = mean(of PBC1-PBC12);
        BI_score  = mean(of BI1-BI12);
        E_score   = mean(of E1-E13);
    run;
%mend;
%add_group(in=survey_a_raw, out=survey_a);
%add_group(in=survey_b_raw, out=survey_b);

* === STEP 3: sample sizes per group =================================;
title "Sample size per urban-stratification group";
proc freq data=survey_a; tables group / nocum nopercent; title2 "SURVEY A"; run;
proc freq data=survey_b; tables group / nocum nopercent; title2 "SURVEY B"; run;
title;

* === STEP 4: per-item descriptives by group ========================;
%macro item_descriptives(ds=, label=);
    title "Per-item Mean + SD by group - &label";
    proc means data=&ds n mean std maxdec=4;
        class group;
        var AT1-AT12 SN1-SN12 PBC1-PBC12 BI1-BI12 E1-E13;
    run;
    title;
%mend;
%item_descriptives(ds=survey_a, label=SURVEY A);
%item_descriptives(ds=survey_b, label=SURVEY B);

* === STEP 5: Cronbach's alpha per construct =========================;
%macro reliability(ds=, label=);
    title "Cronbach's alpha - &label";
    proc corr data=&ds alpha nomiss; var AT1-AT12;   title2 "&label - AT";  run;
    proc corr data=&ds alpha nomiss; var SN1-SN12;   title2 "&label - SN";  run;
    proc corr data=&ds alpha nomiss; var PBC1-PBC12; title2 "&label - PBC"; run;
    proc corr data=&ds alpha nomiss; var BI1-BI12;   title2 "&label - BI";  run;
    proc corr data=&ds alpha nomiss; var E1-E13;     title2 "&label - E";   run;
    title;
%mend;
%reliability(ds=survey_a, label=SURVEY A);
%reliability(ds=survey_b, label=SURVEY B);

* === STEP 6: correlations between construct scores by group =========;
%macro corrmat(ds=, label=);
    title "Pearson correlations of construct scores by group - &label";
    proc corr data=&ds nosimple noprob;
        by group;
        var AT_score SN_score PBC_score BI_score E_score;
    run;
    title;
%mend;
%corrmat(ds=survey_a, label=SURVEY A);
%corrmat(ds=survey_b, label=SURVEY B);

* === STEP 7: independent-samples t-tests ============================;
%macro ttests(ds=, label=);
    title "Independent-samples t-tests (group 1 vs 2) - &label";
    proc ttest data=&ds;
        class group;
        var AT_score SN_score PBC_score BI_score E_score;
    run;
    title;
%mend;
%ttests(ds=survey_a, label=SURVEY A);
%ttests(ds=survey_b, label=SURVEY B);

* === STEP 8: exploratory factor analysis on E1-E13 ==================;
%macro efa_on_e(ds=, label=);
    title "EFA on E1-E13 - &label";
    proc factor data=&ds method=principal mineigen=1 scree
                msa                /* Kaiser-Meyer-Olkin */
                rotate=varimax;
        var E1-E13;
    run;
    title;
%mend;
%efa_on_e(ds=survey_a, label=SURVEY A);
%efa_on_e(ds=survey_b, label=SURVEY B);

* === NOTE ===========================================================;
* PLS-SEM is not estimated here. SAS PROC CALIS performs covariance-based
* SEM, which uses a different estimation algorithm and would not produce
* comparable numbers. This script verifies the descriptives layer only:
* sample sizes, item descriptives, Cronbach's alpha, inter-construct
* correlations, t-tests, and the EFA. Cross-validate the PLS-SEM layer
* with a dedicated PLS tool instead.
*****************************************************************/
