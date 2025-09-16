

********************** Prepare the Data for Local Projections analysis

**** Required STATA Packages 
ssc install tsspell  // sirve para detectar rachas o secuencias en datos de series temporales (ej. varios meses seguidos de sequía)
ssc install gammafit // ajusta una distribución Gamma a los datos de precipitación, que es la base para calcular el índice SPI (Standardized Precipitation Index)

********************** Import the Data from raw_files folder and merge using combine.ado file 
global github_path "https://raw.githubusercontent.com/javierperezcano/Climate-Shocks/main"
// crea una variable global que guarda la dirección del repositorio de GitHub donde están los datos y códigos del paper

*ADO file 
combine_only_SPAIN, saveas("raw_data_only_SPAIN.dta")
// combine descarga todos los ficheros de datos climáticos (CSV) desde GitHub, los une en un solo dataset los guarda en la memoria de Stata y también localmente para no tener que descargarlos otra vez.


********************** Define the global variables 

// Se crean globales para no tener que escribir el nombre completo de las variables cada vez. Esto facilita cambiar nombres si fuera necesario más adelante en el código.

global year year 
global date date 
global date date
global country country_long
global Country_ID Country_ID
global Territory_ID Territory_ID

********************** Rename variables for merging with macroeconomic variables
rename ïtime time
rename cntr_code ${Country_ID}
rename nuts_id ${Territory_ID}

* Formating the Date variable 
gen date = date(time, "YMD")   // convierte la variable "time" (que está como texto YYYYMMDD) en fecha numérica de Stata
format date %td                // aplica formato de fecha día-mes-año para que se vea legible
gen year = year(date)          // extrae el año de la fecha
gen quarter = quarter(date)    // extrae el trimestre calendario (1=Ene-Mar, 2=Abr-Jun, 3=Jul-Sep, 4=Oct-Dic)
gen month = month(date)        // extrae el mes (1=enero, ..., 12=diciembre)

gen calenderyear = yq(year,quarter)   // crea variable de tiempo en formato "año-trimestre" (ej. 2010q1)
format calenderyear %tq               // le da formato de fecha trimestral para que Stata lo interprete bien
sort ${Territory_ID} date // ordena el dataset por territorio, año, trimestre y mes
gen int t_var = ym(year, month)       // crea variable de tiempo en formato "año-mes" como número entero (útil para paneles)
format t_var %tm                      // le da formato de fecha mensual legible

* Drop missing data 
destring pr_mean t_mean, replace
drop if missing(pr_mean) & missing(t_mean) // drop missing values 

* Redefine quarters based on Seasons
gen meteo_quarter = .                               // crea variable vacía para el trimestre meteorológico
replace meteo_quarter  = 1 if month == 12 | month == 1 | month == 2   // asigna invierno (dic, ene, feb)
replace meteo_quarter = 2 if month == 3 | month == 4 | month == 5     // asigna primavera (mar, abr, may)
replace meteo_quarter  = 3 if month == 6 | month == 7 | month == 8    // asigna verano (jun, jul, ago)
replace meteo_quarter  = 4 if month == 9 | month == 10 | month == 11  // asigna otoño (sep, oct, nov)

* Adjust the year for December data for meteorological year 
gen meteo_only_year = year                          // copia el año calendario
replace meteo_only_year= year +1 if month == 12     // si es diciembre, suma 1 (diciembre se cuenta en el año siguiente meteorológico)
gen meteoyear = yq(meteo_only_year,meteo_quarter)   // crea variable de año-trimestre meteorológico
format meteoyear %tq    

*********************************************************************************************************************************************
*********************************************************************************************************************************************
********************************************************** DEFINE HEATWAVES *****************************************************************
*********************************************************************************************************************************************
*********************************************************************************************************************************************

**destring t_diff_1991_2020, replace dpcomma ignore(" ")
**bysort ${Country_ID} ${Territory_ID} meteo_only_year: egen annual_avg_temp_dev = mean(t_diff_1991_2020) 
// calcula la desviación anual media de la temperatura respecto al periodo 1991-2020 por país, territorio y año meteorológico


***** Quarterly

** Generate long run means both for meteorological and calendar year
** Calcula la climatología histórica 1991–2020 por territorio y trimestre (meteo o calendario según el bloque). Promedia todas las observaciones de 1991–2020 dentro de cada grupo (p.ej., "Madrid–verano", primer bloque, o "Madrid-junio,julio y agosto, segundo bloque), y guarda un único valor constante por grupo. Será la referencia para calcular anomalías (observado – climatología).

* Generate long run mean (1991_2020) for meteorological year in each quarter 
egen aux = mean(t_mean) if meteo_only_year > 1990 & meteo_only_year < 2021 & meteo_only_year !=.  , by (${Territory_ID} meteo_quarter) 
// obtiene la temperatura media histórica (1991-2020) por territorio y trimestre meteorológico
egen meteor_avgtemp_quarter_hist = min(aux) , by (${Territory_ID} meteo_quarter) 
// guarda ese promedio como valor constante para cada territorio-trimestre
drop aux

* Generate long run mean (1991_2020) for calendar year in each quarter 
egen aux = mean(t_mean) if year > 1990 & year < 2021 & year !=.  , by (${Territory_ID} quarter) 
// obtiene la temperatura media histórica (1991-2020) por territorio y trimestre calendario
egen calendar_avgtemp_quarter_hist = min(aux) , by (${Territory_ID} quarter) 
// guarda ese promedio como valor constante para cada territorio-trimestre calendario
drop aux 

** Generate quarterly absolute temperature averages both for meteorological and calendar year 
** Calcula la media trimestral observada en cada año específico por territorio (meteo o calendario según el bloque). Promedia las observaciones de los meses que forman cada trimestre dentro de ese año (p.ej., "Madrid–invierno 2015", primer bloque, o "Madrid–Q1 2015", segundo bloque), y guarda un valor distinto para cada territorio–año–trimestre. Será el valor observado que luego se compara con la climatología para obtener anomalías (observado – climatología).

egen temp_meteo_quarter = mean(t_mean), by (${Territory_ID} meteo_quarter meteo_only_year)  
// calcula la temperatura media trimestral absoluta agrupando por territorio + trimestre meteorológico (dic–feb, mar–may, jun–ago, sep–nov) + año meteorológico (diciembre cuenta para el año siguiente)  
// resultado: la temperatura media de invierno/primavera/verano/otoño en cada año meteorológico y territorio  
egen temp_quarter = mean (t_mean), by (${Territory_ID} quarter year)  
// calcula la temperatura media trimestral absoluta agrupando por territorio + trimestre calendario (Q1=ene–mar, Q2=abr–jun, Q3=jul–sep, Q4=oct–dic) + año calendario  
// resultado: la temperatura media de cada trimestre calendario en cada año y territorio  



** Generate quarterly deviations from long run mean 
gen temp_meteo_quarter_dev = temp_meteo_quarter -  meteor_avgtemp_quarter_hist   // desviación trimestral de la media histórica (1991-2020) usando trimestres meteorológicos
gen temp_calendar_quarter_dev = temp_quarter - calendar_avgtemp_quarter_hist     // desviación trimestral de la media histórica (1991-2020) usando trimestres calendario


***** Monthly

** Generate long run means both for meteorological and calendar year

* Generate long run mean (1991_2020) for meteorological year in each month 
egen aux = mean(t_mean) if meteo_only_year > 1990 & meteo_only_year < 2021 & meteo_only_year !=.  , by (${Territory_ID} month) 
// obtiene la temperatura media histórica (1991-2020) por territorio y mes meteorológico
egen meteor_avgtemp_month_hist = min(aux) , by (${Territory_ID} month) 
// guarda ese promedio como valor constante para cada territorio-mes
drop aux 

* Generate long run mean (1991_2020) for calendar year in each month 
egen aux = mean(t_mean) if year > 1990 & year < 2021 & year !=.  , by (${Territory_ID} month) 
// obtiene la temperatura media histórica (1991-2020) por territorio y mes calendario
egen calendar_avgtemp_month_hist = min(aux) , by (${Territory_ID} month) 
// guarda ese promedio como valor constante para cada territorio-mes calendario
drop aux 


** Generate monthly absolute temperature averages both for meteorological and calendar year 
egen temp_meteo_month = mean(t_mean), by (month meteo_only_year) // calcula la temperatura media mensual absoluta por año meteorológico
egen temp_month = mean (t_mean), by (month year) // calcula la temperatura media mensual absoluta por año calendario

* Generate monthly deviations from long run mean 
gen temp_meteo_month_dev = temp_meteo_month -  meteor_avgtemp_month_hist   // desviación mensual de la media histórica (1991-2020) usando meses
gen temp_calendar_month_dev = temp_month - calendar_avgtemp_month_hist     // desviación trimestral de la media histórica (1991-2020) usando meses calendario

****************** Create weather dummies

gen winter = .
replace winter = 1 if meteo_quarter ==1
gen spring = .
replace spring = 1 if meteo_quarter ==2
gen summer = .
replace summer = 1 if meteo_quarter ==3
gen autumn = .
replace autumn = 1 if meteo_quarter ==4


**** Variables for heat shocks 


****** Quarterly (only for meteorological calendar)

** Baseline 

* Verano
gen  hotsummer_2C =. 
replace hotsummer_2C = 1 if  temp_meteo_quarter_dev >2 & summer==1 &  temp_meteo_quarter_dev!=.
// Marca con 1 aquellos veranos en los que la temperatura media trimestral estuvo más de 2 °C por encima de lo normal en un territorio y año dados. Más en detalle, asigna el valor 1 a la variable hotsummer_2C bajo la condición de que la desviación de temperatura en el trimestre meteorológico (temp_meteo_quarter_dev) sea mayor a 2 °C respecto a la climatología 1991–2020. Además, el trimestre debe ser verano (junio–agosto) y la variable no puede estar vacía (se evita asignar valores a los missing).
replace hotsummer_2C = 1 if temp_meteo_quarter_dev == 2 & summer==1 & temp_meteo_quarter_dev!=.
replace hotsummer_2C = 0 if  temp_meteo_quarter_dev<2 & summer==1 &  temp_meteo_quarter_dev!=.

* Otoño
gen  hotautumn_2C =. 
replace hotautumn_2C = 1 if  temp_meteo_quarter_dev >2 & autumn==1 &  temp_meteo_quarter_dev!=.
replace hotautumn_2C = 1 if temp_meteo_quarter_dev == 2 & autumn==1 & temp_meteo_quarter_dev!=.
replace hotautumn_2C = 0 if  temp_meteo_quarter_dev<2 & autumn==1 &  temp_meteo_quarter_dev!=.

* Invierno
gen  hotwinter_2C =. 
replace hotwinter_2C = 1 if  temp_meteo_quarter_dev >2 & winter==1 &  temp_meteo_quarter_dev!=.
replace hotwinter_2C = 1 if temp_meteo_quarter_dev == 2 & winter==1 & temp_meteo_quarter_dev!=.
replace hotwinter_2C = 0 if  temp_meteo_quarter_dev<2 & winter==1 &  temp_meteo_quarter_dev!=.

* Primavera
gen  hotspring_2C =. 
replace hotspring_2C = 1 if  temp_meteo_quarter_dev >2 & spring==1 &  temp_meteo_quarter_dev!=.
replace hotspring_2C = 1 if temp_meteo_quarter_dev == 2 & spring==1 & temp_meteo_quarter_dev!=.
replace hotspring_2C = 0 if  temp_meteo_quarter_dev<2 & spring==1 &  temp_meteo_quarter_dev!=.

** Robustness check 1.75

gen  hotsummer_175C =. 
replace hotsummer_175C = 1 if  temp_meteo_quarter_dev >1.75 & summer==1 &  temp_meteo_quarter_dev!=.
replace hotsummer_175C = 1 if temp_meteo_quarter_dev == 1.75 & summer==1 & temp_meteo_quarter_dev!=.
replace hotsummer_175C = 0 if  temp_meteo_quarter_dev<1.75 & summer==1 &  temp_meteo_quarter_dev!=.

gen  hotautumn_175C =. 
replace hotautumn_175C = 1 if  temp_meteo_quarter_dev >1.75 & autumn==1 &  temp_meteo_quarter_dev!=.
replace hotautumn_175C = 1 if temp_meteo_quarter_dev == 1.75 & autumn==1 & temp_meteo_quarter_dev!=.
replace hotautumn_175C = 0 if  temp_meteo_quarter_dev<1.75 & autumn==1 &  temp_meteo_quarter_dev!=.

gen  hotwinter_175C =. 
replace hotwinter_175C = 1 if  temp_meteo_quarter_dev >1.75 & winter==1 &  temp_meteo_quarter_dev!=.
replace hotwinter_175C = 1 if temp_meteo_quarter_dev == 1.75 & winter==1 & temp_meteo_quarter_dev!=.
replace hotwinter_175C = 0 if  temp_meteo_quarter_dev<1.75 & winter==1 &  temp_meteo_quarter_dev!=.

gen  hotspring_175C =. 
replace hotspring_175C = 1 if  temp_meteo_quarter_dev >1.75 & spring==1 &  temp_meteo_quarter_dev!=.
replace hotspring_175C = 1 if temp_meteo_quarter_dev == 1.75 & spring==1 & temp_meteo_quarter_dev!=.
replace hotspring_175C = 0 if  temp_meteo_quarter_dev<1.75 & spring==1 &  temp_meteo_quarter_dev!=.


** Robustness check 2.25

gen  hotsummer_225C =. 
replace hotsummer_225C = 1 if  temp_meteo_quarter_dev >2.25 & summer==1 &  temp_meteo_quarter_dev!=.
replace hotsummer_225C = 1 if temp_meteo_quarter_dev == 2.25 & summer==1 & temp_meteo_quarter_dev!=.
replace hotsummer_225C = 0 if  temp_meteo_quarter_dev<2.25 & summer==1 &  temp_meteo_quarter_dev!=.
replace hotsummer_225C = 0 if  temp_meteo_quarter_dev<-2.25 & summer==1 &  temp_meteo_quarter_dev!=.


gen  hotautumn_225C =. 
replace hotautumn_225C = 1 if  temp_meteo_quarter_dev >2.25 & autumn==1 &  temp_meteo_quarter_dev!=.
replace hotautumn_225C = 1 if temp_meteo_quarter_dev == 2.25 & autumn==1 & temp_meteo_quarter_dev!=.
replace hotautumn_225C = 0 if  temp_meteo_quarter_dev<2.25 & autumn==1 &  temp_meteo_quarter_dev!=.
replace hotautumn_225C = 0 if  temp_meteo_quarter_dev<-2.25 & autumn==1 &  temp_meteo_quarter_dev!=.

gen  hotwinter_225C =. 
replace hotwinter_225C = 1 if  temp_meteo_quarter_dev >2.25 & winter==1 &  temp_meteo_quarter_dev!=.
replace hotwinter_225C = 1 if temp_meteo_quarter_dev == 2.25 & winter==1 & temp_meteo_quarter_dev!=.
replace hotwinter_225C = 0 if  temp_meteo_quarter_dev<2.25 & winter==1 &  temp_meteo_quarter_dev!=.
replace hotwinter_225C = 0 if  temp_meteo_quarter_dev<-2.25 & winter==1 &  temp_meteo_quarter_dev!=.


gen  hotspring_225C =. 
replace hotspring_225C = 1 if  temp_meteo_quarter_dev >2.25 & spring==1 &  temp_meteo_quarter_dev!=.
replace hotspring_225C = 1 if temp_meteo_quarter_dev == 2.25 & spring==1 & temp_meteo_quarter_dev!=.
replace hotspring_225C = 0 if  temp_meteo_quarter_dev<2.25 & spring==1 &  temp_meteo_quarter_dev!=.
replace hotspring_225C = 0 if  temp_meteo_quarter_dev<-2.25 & spring==1 &  temp_meteo_quarter_dev!=.


****** Monthly 

** Baseline 

gen  hotmonthsummer_2C =. 
replace hotmonthsummer_2C = 1 if  temp_meteo_month_dev >2 & summer==1 &  temp_meteo_quarter_dev!=.
// Marca con 1 aquellos meses veranos en los que la temperatura media trimestral estuvo más de 2 °C por encima de lo normal en un territorio y año dados. Más en detalle, asigna el valor 1 a la variable hotsummer_2C bajo la condición de que la desviación de temperatura en el mes meteorológico (temp_meteo_month_dev) sea mayor a 2 °C respecto a la climatología 1991–2020. Además, el mes debe ser verano (junio–agosto) y la variable no puede estar vacía (se evita asignar valores a los missing).
replace hotmonthsummer_2C = 1 if temp_meteo_month_dev == 2 & summer==1 & temp_meteo_quarter_dev!=.
replace hotmonthsummer_2C = 0 if  temp_meteo_month_dev<2 & summer==1 &  temp_meteo_quarter_dev!=.

* Otoño
gen  hotmonthautumn_2C =. 
replace hotmonthautumn_2C = 1 if  temp_meteo_month_dev >2 & autumn==1 &  temp_meteo_quarter_dev!=.
replace hotmonthautumn_2C = 1 if temp_meteo_month_dev == 2 & autumn==1 & temp_meteo_quarter_dev!=.
replace hotmonthautumn_2C = 0 if  temp_meteo_month_dev<2 & autumn==1 &  temp_meteo_quarter_dev!=.

* Invierno
gen  hotmonthwinter_2C =. 
replace hotmonthwinter_2C = 1 if  temp_meteo_month_dev >2 & winter==1 &  temp_meteo_quarter_dev!=.
replace hotmonthwinter_2C = 1 if temp_meteo_month_dev == 2 & winter==1 & temp_meteo_quarter_dev!=.
replace hotmonthwinter_2C = 0 if  temp_meteo_month_dev<2 & winter==1 &  temp_meteo_quarter_dev!=.

* Primavera
gen  hotmonthspring_2C =. 
replace hotmonthspring_2C = 1 if  temp_meteo_month_dev >2 & spring==1 &  temp_meteo_quarter_dev!=.
replace hotmonthspring_2C = 1 if temp_meteo_month_dev == 2 & spring==1 & temp_meteo_quarter_dev!=.
replace hotmonthspring_2C = 0 if  temp_meteo_month_dev<2 & spring==1 &  temp_meteo_quarter_dev!=.

** Robustness check 1.75

gen  hotmonthsummer_175C =. 
replace hotmonthsummer_175C = 1 if  temp_meteo_month_dev >1.75 & summer==1 &  temp_meteo_quarter_dev!=.
replace hotmonthsummer_175C = 1 if temp_meteo_month_dev == 1.75 & summer==1 & temp_meteo_quarter_dev!=.
replace hotmonthsummer_175C = 0 if  temp_meteo_month_dev<1.75 & summer==1 &  temp_meteo_quarter_dev!=.

gen  hotmonthautumn_175C =. 
replace hotmonthautumn_175C = 1 if  temp_meteo_month_dev >1.75 & autumn==1 &  temp_meteo_quarter_dev!=.
replace hotmonthautumn_175C = 1 if temp_meteo_month_dev == 1.75 & autumn==1 & temp_meteo_quarter_dev!=.
replace hotmonthautumn_175C = 0 if  temp_meteo_month_dev<1.75 & autumn==1 &  temp_meteo_quarter_dev!=.

gen  hotmonthwinter_175C =. 
replace hotmonthwinter_175C = 1 if  temp_meteo_month_dev >1.75 & winter==1 &  temp_meteo_quarter_dev!=.
replace hotmonthwinter_175C = 1 if temp_meteo_month_dev == 1.75 & winter==1 & temp_meteo_quarter_dev!=.
replace hotmonthwinter_175C = 0 if  temp_meteo_month_dev<1.75 & winter==1 &  temp_meteo_quarter_dev!=.

gen  hotmonthspring_175C =. 
replace hotmonthspring_175C = 1 if  temp_meteo_month_dev >1.75 & spring==1 &  temp_meteo_quarter_dev!=.
replace hotmonthspring_175C = 1 if temp_meteo_month_dev == 1.75 & spring==1 & temp_meteo_quarter_dev!=.
replace hotmonthspring_175C = 0 if  temp_meteo_month_dev<1.75 & spring==1 &  temp_meteo_quarter_dev!=.


** Robustness check 2.25

gen  hotmonthsummer_225C =. 
replace hotmonthsummer_225C = 1 if  temp_meteo_month_dev >2.25 & summer==1 &  temp_meteo_quarter_dev!=.
replace hotmonthsummer_225C = 1 if temp_meteo_month_dev == 2.25 & summer==1 & temp_meteo_quarter_dev!=.
replace hotmonthsummer_225C = 0 if  temp_meteo_month_dev<2.25 & summer==1 &  temp_meteo_quarter_dev!=.
replace hotmonthsummer_225C = 0 if  temp_meteo_month_dev<-2.25 & summer==1 &  temp_meteo_quarter_dev!=.


gen  hotmonthautumn_225C =. 
replace hotmonthautumn_225C = 1 if  temp_meteo_month_dev >2.25 & autumn==1 &  temp_meteo_quarter_dev!=.
replace hotmonthautumn_225C = 1 if temp_meteo_month_dev == 2.25 & autumn==1 & temp_meteo_quarter_dev!=.
replace hotmonthautumn_225C = 0 if  temp_meteo_month_dev<2.25 & autumn==1 &  temp_meteo_quarter_dev!=.
replace hotmonthautumn_225C = 0 if  temp_meteo_month_dev<-2.25 & autumn==1 &  temp_meteo_quarter_dev!=.

gen  hotmonthwinter_225C =. 
replace hotmonthwinter_225C = 1 if  temp_meteo_month_dev >2.25 & winter==1 &  temp_meteo_quarter_dev!=.
replace hotmonthwinter_225C = 1 if temp_meteo_month_dev == 2.25 & winter==1 & temp_meteo_quarter_dev!=.
replace hotmonthwinter_225C = 0 if  temp_meteo_month_dev<2.25 & winter==1 &  temp_meteo_quarter_dev!=.
replace hotmonthwinter_225C = 0 if  temp_meteo_month_dev<-2.25 & winter==1 &  temp_meteo_quarter_dev!=.


gen  hotmonthspring_225C =. 
replace hotmonthspring_225C = 1 if  temp_meteo_month_dev >2.25 & spring==1 &  temp_meteo_quarter_dev!=.
replace hotmonthspring_225C = 1 if temp_meteo_month_dev == 2.25 & spring==1 & temp_meteo_quarter_dev!=.
replace hotmonthspring_225C = 0 if  temp_meteo_month_dev<2.25 & spring==1 &  temp_meteo_quarter_dev!=.
replace hotmonthspring_225C = 0 if  temp_meteo_month_dev<-2.25 & spring==1 &  temp_meteo_quarter_dev!=.

*********************************************************************************************************************************************
*********************************************************************************************************************************************
********************************************************** DEFINE FLOODS ********************************************************************
*********************************************************************************************************************************************
*********************************************************************************************************************************************

****** Declare panel data
egen ID_var = group(Territory_ID)   // crea un identificador numérico de panel
xtset ID_var t_var                  // declara los datos como panel: dimensión espacial (ID_var) × temporal (t_var)

********** Estimate SPI index to predict hazard of floods 

****** Baseline metric (flood metric using three days maximum precipitation)

*** Limpieza de datos
drop if pr_total == 0 // elimina observaciones donde la precipitación total es cero (limpieza de datos)

*** Estimación de la distribución Gamma para la precipitación máxima acumulada en 3 días, que servirá de base para construir el SPI de 3 días. Transformación de la precipitación bruta en probabilidades acumuladas bajo la distribución Gamma ajustada. Conversión de probabilidades a un índice estandarizado (SPI), comparable entre regiones y periodos.

gammafit pr_max_3day, vce(cluster Territory_ID)  
// Ajusta una distribución Gamma a la precipitación máxima acumulada en 3 días, con errores estándar agrupados por territorio  
// Se utiliza una distribución Gamma porque, como explica el paper, la precipitación no se distribuye normalmente: es una variable continua, no negativa y con fuerte asimetría a la derecha (muchos valores bajos y pocos eventos extremos muy altos). La distribución Gamma está pensada justamente para modelar este tipo de fenómenos climáticos, ofreciendo un ajuste más realista que la normal. Esto permite transformar la precipitación a probabilidades acumuladas y luego estandarizarla en un índice comparable entre regiones y periodos (SPI).

// La variable pr_max_3day mide la precipitación máxima acumulada en tres días consecutivos dentro de un mes. Por ejemplo, si en A Coruña en enero de 1990 toma valor 62.13, significa que en ese mes el episodio más lluvioso de tres días seguidos sumó 62.13 mm en total.
 
gen Probability_3 = .  
// Crea variable vacía que contendrá la probabilidad acumulada bajo la distribución Gamma

replace Probability_3 = gammap(e(alpha), pr_max_3day/e(beta))  
// Calcula la probabilidad acumulada (CDF) de que ocurra un valor de precipitación máxima en 3 días menor o igual al observado, según la distribución Gamma ajustada con parámetros alpha y beta. En otras palabras, transforma el valor bruto de lluvia (pr_max_3day) en una probabilidad entre 0 y 1 que refleja cuán extremo es ese episodio dentro de la distribución histórica estimada.
// Si Probability_3 se acerca a 1, quiere decir que el valor observado de pr_max_3day está en la cola superior de la distribución, es decir, que es un episodio de lluvia muy intenso y poco frecuente. Si Probability_3 está cerca de 0, ocurre lo contrario: el episodio es muy bajo, señal de sequía o ausencia de lluvias en ese período.
// Por ejemplo, en A Coruña, enero de 1990, pr_max_3day = 62.13 con Probability_3=0.9392976. Esto se interpreta como que el 94% de los episodios de lluvia de 3 días son menores o iguales a 62.13 mm, y solo un 5% son más extremos.

gen SPI_3 = invnorm(Probability_3)  
// Convierte la probabilidad con invnorm() en un SPI (Standardized Precipitation Index), que se centra en 0 y permite comparaciones entre regiones y periodos: SPI > 2 es un evento extremadamente húmedo, SPI < -2 extremadamente seco.


gen hazard_max3days = .  
// crea variable vacía para clasificar el nivel de humedad/sequía

replace hazard_max3days = 7 if  SPI_3 >= 2                    // clasifica como "extreme wet" (evento de lluvia extrema)
replace hazard_max3days = 6 if inrange(SPI_3,1.5,1.999)       // clasifica como "very wet"
replace hazard_max3days = 5 if inrange(SPI_3,1.0,1.499)       // clasifica como "moderate wet"
replace hazard_max3days = 4 if inrange(SPI_3,-0.999,0.999)    // clasifica como "near normal"
replace hazard_max3days = 3 if inrange(SPI_3,-1.499,-1.0)     // clasifica como "moderate dryness"
replace hazard_max3days = 2 if inrange(SPI_3,-1.999,-1.5)     // clasifica como "severe dryness"
replace hazard_max3days = 1 if SPI_3 <= -2                    // clasifica como "extreme dryness"
replace hazard_max3days = . if SPI_3 == .                     // missing si SPI no está definido

g hazard_max3days_label = word("extremely_dry very_dry moderately_dry normal_precipitation moderately_wet very_wet extremely_wet", hazard_max3days)  
// crea variable con etiquetas de texto según la clasificación numérica anterior

gen flood_max3days = .  
// crea variable binaria para identificar inundaciones extremas

replace flood_max3days = 1 if hazard_max3days == 7  // asigna 1 si el mes se clasifica como "extremely wet" (lluvia extrema)
replace flood_max3days = 0 if flood_max3days == .   // asigna 0 al resto
// browse if pr_total == 0 - abre el visor de datos solo con las observaciones donde pr_total = 0

*** Identificación de episodios consecutivos (spells) de inundaciones extremas en series temporales de panel.

tsset ID_var t_var  
// declara los datos en formato panel: ID territorial y variable temporal

tsspell, pcond(flood_max3days)  
// detecta secuencias (spells) de periodos consecutivos con flood_max3days=1


*** Construcción de indicadores de eventos de inundación a nivel anual y trimestral según la presencia de spells.

* Anual
egen max = max(_seq), by(ID_var year)  //  calcula la secuencia máxima por territorio y año (indica si en ese año hubo algún spell de inundación extrema)
gen annual_flood_event_max3days = .  // crea variable de evento anual de inundación (dummy)
replace annual_flood_event_max3days = 1 if max > 0           // asigna 1 si hubo al menos un spell de inundación extrema en el año
replace annual_flood_event_max3days = 0 if annual_flood_event_max3days == .  // asigna 0 si no hubo

* Quarterly
egen max_quarter = max(_seq), by(ID_var year quarter)  
gen quarter_flood_event_max3days = .  // crea variable de evento trimestral de inundación (dummy)
replace quarter_flood_event_max3days = 1 if max_quarter > 0           // asigna 1 si hubo al menos un spell de inundación extrema en el trimestre
replace quarter_flood_event_max3days = 0 if quarter_flood_event_max3days == .  // asigna 0 si no hubo


sort ${Territory_ID} t_var  
// ordena los datos por territorio y tiempo

drop _seq _spell _end max  
// elimina variables auxiliares generadas por tsspell

****** Robustness check: se repite la estimación del SPI pero usando la precipitación total mensual acumulada en lugar de la máxima en 3 días.

gammafit pr_total, vce(cluster Territory_ID)
gen Probability_1 = .
replace Probability_1 = gammap(e(alpha), pr_total/e(beta))
gen SPI_1 = invnorm(Probability_1) // SPI Index using average precipitaion using monthly accumulation period

** Define SPI_1 index using monthly accumulation

gen hazard_monthlyaccum = .  
// crea variable vacía para clasificar el nivel de humedad/sequía con base en el SPI mensual acumulado

replace hazard_monthlyaccum = 7 if  SPI_1 >= 2 // extreme wet  
// clasifica como "extremadamente húmedo" cuando el SPI mensual ≥ 2 (evento muy raro y extremo de exceso de lluvia)

replace hazard_monthlyaccum = 6 if    inrange(SPI_1,1.5,1.999)  // very wet  
// clasifica como "muy húmedo" cuando el SPI está entre 1.5 y 1.999

replace hazard_monthlyaccum = 5 if     inrange(SPI_1,1.0,1.499)  // moderate wet  
// clasifica como "moderadamente húmedo" cuando el SPI está entre 1.0 y 1.499

replace hazard_monthlyaccum = 4 if inrange(SPI_1,-0.999,0.999) // near normal  
// clasifica como "casi normal" cuando el SPI está entre -0.999 y 0.999

replace hazard_monthlyaccum = 3 if inrange(SPI_1,-1.499,-1.0) // moderate dryness  
// clasifica como "sequía moderada" cuando el SPI está entre -1.499 y -1.0

replace hazard_monthlyaccum = 2 if inrange(SPI_1,-1.999,-1.5)  // severe dryness  
// clasifica como "sequía severa" cuando el SPI está entre -1.999 y -1.5

replace hazard_monthlyaccum = 1 if SPI_1 <=-2 // extreme dryness  
// clasifica como "sequía extrema" cuando el SPI mensual ≤ -2

replace hazard_monthlyaccum = . if SPI_1 == .  
// deja en missing cuando el SPI mensual está vacío

g flood_monthlyaccum_label = word("extremely_dry very_dry moderately_dry normal_precipitation moderately_wet very_wet extremely_wet", hazard_monthlyaccum)  
// crea una variable de etiquetas de texto para describir cada categoría (de sequía extrema a lluvia extrema)


gen flood_monthlyaccum = .  
// crea un dummy para inundaciones basado en el SPI mensual

replace flood_monthlyaccum  = 1 if hazard_monthlyaccum == 7  
// define inundación (=1) si el mes es extremadamente húmedo

replace flood_monthlyaccum  = 0 if flood_monthlyaccum ==.  
// pone 0 en el resto de observaciones (no inundación)

tsset ID_var t_var  
// declara los datos como panel temporal (territorio por mes)

tsspell, pcond(flood_monthlyaccum)  
// identifica rachas consecutivas (spells) de inundaciones

egen max  = max(_seq), by(ID_var year)  
// toma la máxima duración de la racha de inundaciones dentro de cada año y territorio

gen flood_event_monthlyaccum = .  
// crea dummy final de evento de inundación (a nivel anual)

replace flood_event_monthlyaccum = 1 if max > 0  
// si hubo al menos un episodio en el año, marca el año como 1 (hubo evento de inundación)

replace flood_event_monthlyaccum = 0 if flood_event_monthlyaccum == .  
// si no hubo ningún episodio, asigna 0 (no hubo inundación)

drop _seq _spell _end max  
// elimina variables temporales creadas por tsspell


*********************************************************************************************************************************************
*********************************************************************************************************************************************
********************************************************** DEFINE DROUGHTS ******************************************************************
*********************************************************************************************************************************************
*********************************************************************************************************************************************

* NOTE: Only a quarterly measure is available here

******************* Precipitation Anomalies to define droughts
** Define el índice SPI trimestral con precipitación acumulada en tres meses, comparando cada valor observado con la distribución Gamma ajustada (1991–2020). Clasifica los trimestres en categorías de humedad o sequía y genera un indicador anual de sequía (=1 si al menos un trimestre presenta sequía severa o extrema).

// A partir de la precipitación acumulada en 3 meses, se define un índice SPI trimestral para identificar sequías.

* SPI Index with quarterly accumulation period 
egen pr_accumulated = mean(pr_total), by (${Territory_ID} quarter year) 
// calcula la precipitación media trimestral (promedia los meses de cada trimestre calendario, TAMBIÉN SERÍA INTERESANTE HACERLO POR TRIMESTRE METEOROLÓGICO por territorio y año)

* Collapse data to quarterly level and estimate the SPI index based on 3 months accumulation period
* keep if month == 2 | month == 5 | month == 8 | month == 11 
// reduce el dataset a observaciones trimestrales: febrero (Q1), mayo (Q2), agosto (Q3) y noviembre (Q4) representan cada trimestre

gammafit pr_accumulated, vce(cluster Territory_ID)  
// ajusta una distribución Gamma a la precipitación trimestral acumulada, con errores agrupados por territorio

gen Probability_drought = .  
// variable vacía para almacenar probabilidades acumuladas bajo la distribución Gamma

replace Probability_drought = gammap(e(alpha), pr_accumulated/e(beta))  
// transforma cada valor de precipitación trimestral en una probabilidad (CDF) entre 0 y 1 según la Gamma ajustada

gen SPI_drought = invnorm(Probability_drought)  
// convierte la probabilidad en un índice SPI trimestral estandarizado (similar a un z-score de la distribución normal)

** define hazard
******************* define SPI_drought index using accumulated precipitaion for 3 months
gen hazard_drought = .  
// variable vacía para clasificar la severidad de la sequía o humedad según SPI trimestral

replace hazard_drought = 7 if  SPI_drought >= 2              // evento extremadamente húmedo
replace hazard_drought = 6 if inrange(SPI_drought,1.5,1.999) // muy húmedo
replace hazard_drought = 5 if inrange(SPI_drought,1.0,1.499) // moderadamente húmedo
replace hazard_drought = 4 if inrange(SPI_drought,-0.999,0.999) // condiciones normales
replace hazard_drought = 3 if inrange(SPI_drought,-1.499,-1.0) // sequía moderada
replace hazard_drought = 2 if inrange(SPI_drought,-1.999,-1.5) // sequía severa
replace hazard_drought = 1 if SPI_drought <=-2              // sequía extrema
replace hazard_drought = . if SPI_drought == .              // missing si no hay SPI

g hazarddrought = word("extremely_dry_quarter very_dry_quarter moderately_dry_quarter normal_precipitation_quarter moderately_wet_quarter very_wet_quarter extremely_wet_quarter", hazard_drought)  
// crea variable de etiquetas de texto según la clasificación numérica anterior

// Muestra la etiqueta solo en el 3er mes del trimestre
bysort Territory_ID year quarter (month): gen byte is_qend = _n == _N // Marca el último mes disponible de cada trimestre (robusto si falta algún mes)
gen str40 hazarddrought_pretty = ""
replace hazarddrought_pretty = hazarddrought if is_qend
drop is_qend 
drop hazarddrought
rename hazarddrought_pretty hazarddrought

gen indicator_rainfall = .  
// dummy auxiliar para sequías

replace indicator_rainfall = 1 if hazard_drought == 1 | hazard_drought == 2  
// toma valor 1 si el trimestre corresponde a sequía extrema o severa

replace indicator_rainfall = 0 if hazard_drought > 2  
// toma valor 0 en el resto de casos (condiciones normales o húmedas)


** Para contar si en un año hubo sequías o nombre

/*

tsset ID_var t_var  
// declara los datos como panel (territorio × tiempo)

* ssc install tsspell
tsspell, pcond(indicator_rainfall)    
// detecta rachas (spells) consecutivas de sequía (indicator_rainfall=1)

egen max = max(indicator_rainfall), by(ID_var year)    
// obtiene el valor máximo de indicator_rainfall dentro de cada territorio-año (básicamente si en algún trimestre hubo sequía)

gen drought_event = .  
// dummy final de sequía a nivel anual

replace drought_event = 1 if max == 1  
// marca el año como sequía (=1) si hubo al menos un trimestre con sequía

replace drought_event = 0 if drought_event == . & max == 0  
// asigna 0 si no hubo sequía en todo el año

drop max _end _spell _seq  
// elimina variables auxiliares generadas por tsspell y egen

sort ${Territory_ID} t_var  
// ordena datos por territorio y tiempo



**************** convert the quarterly data in annual series 

bysort ${Territory_ID} ${year}: egen aux_hotsummer_2C = max(hotsummer_2C)
bysort ${Territory_ID} ${year}: egen aux_hotwinter_2C= max(hotwinter_2C)
bysort ${Territory_ID} ${year}: egen aux_hotautumn_2C = max(hotautumn_2C)
bysort ${Territory_ID} ${year}: egen aux_hotspring_2C= max(hotspring_2C)

bysort ${Territory_ID} ${year}: egen aux_hotsummer_175C = max(hotsummer_175C)
bysort ${Territory_ID} ${year}: egen aux_hotwinter_175C= max(hotwinter_175C)
bysort ${Territory_ID} ${year}: egen aux_hotautumn_175C = max(hotautumn_175C)
bysort ${Territory_ID} ${year}: egen aux_hotspring_175C= max(hotspring_175C)

bysort ${Territory_ID} ${year}: egen aux_hotsummer_225C = max(hotsummer_225C)
bysort ${Territory_ID} ${year}: egen aux_hotwinter_225C= max(hotwinter_225C)
bysort ${Territory_ID} ${year}: egen aux_hotautumn_225C = max(hotautumn_225C)
bysort ${Territory_ID} ${year}: egen aux_hotspring_225C= max(hotspring_225C)

drop hotsummer_2C hotautumn_2C hotwinter_2C hotspring_2C hotsummer_175C hotautumn_175C hotwinter_175C hotspring_175C hotsummer_225C hotautumn_225C hotwinter_225C hotspring_225C 

rename aux_hotsummer_2C hotsummer_2C
rename aux_hotwinter_2C hotwinter_2C
rename aux_hotautumn_2C  hotautumn_2C
rename aux_hotspring_2C hotspring_2C

rename aux_hotsummer_175C hotsummer_175C
rename aux_hotspring_175C hotspring_175C
rename aux_hotwinter_175C hotwinter_175C
rename aux_hotautumn_175C hotautumn_175C

rename aux_hotsummer_225C hotsummer_225C
rename aux_hotspring_225C  hotspring_225C 
rename aux_hotwinter_225C  hotwinter_225C 
rename aux_hotautumn_225C hotautumn_225C 



**** Define variable to capture baseline climate of regions  

*** Hot/medium/cold regions terciles (1 "Cold" 2 "Medium" 3 "Hot")
xtile Baseline_climate=meteor_avgtemp_quarter_hist if summer ==1,n(3)
by Territory_ID, sort: fillmissing Baseline_climate, with(max) 

keep if quarter == 3 // select any quarter to convert it into annual data

keep Territory_ID Country_ID name_latn year drought_event flood_event_monthlyaccum flood_event_max3days hotwinter_2C hotsummer_2C hotautumn_2C hotspring_2C hotsummer_175C hotwinter_175C hotautumn_175C hotspring_175C hotsummer_225C hotwinter_225C hotautumn_225C hotspring_225C Baseline_climate 

*/

**** Label variables 

label variable year "Year"
** label variable Baseline_climate "1Cold 2medium 3hot regions"
** label variable flood_event_max3days "Flood event: Baseline"
label variable flood_event_monthlyaccum "Flood event: robust check"
label variable hazarddrought "Drought event: Baseline"

label variable hotsummer_2C "Heatwave summer 2Celcius: Baseline"
label variable hotsummer_175C "Heatwave summer 1.75Celcius: Robustness check"
label variable hotsummer_225C "Heatwave summer 2.25Celcius: Robustness check"

label variable hotspring_2C "Heatwave spring 2Celcius"
label variable hotspring_175C "Heatwave spring 1.75Celcius"
label variable hotspring_225C "Heatwave spring 2.25Celcius"

label variable hotwinter_2C "Heatwave winter 2Celcius"
label variable hotwinter_175C "Heatwave  winter 1.75Celcius"
label variable hotwinter_225C "Heatwave  winter 2.25Celcius"

label variable hotautumn_2C "Heatwave autumn 2Celcius"
label variable hotautumn_175C "Heatwave autumn 1.75Celcius"
label variable hotautumn_225C "Heatwave  autumn 2.25Celcius"

label variable hotmonthsummer_2C "Heatwave month in summer 2Celcius: Baseline"
label variable hotmonthsummer_175C "Heatwave month in summer 1.75Celcius: Robustness check"
label variable hotmonthsummer_225C "Heatwave summer 2.25Celcius: Robustness check"

label variable hotmonthspring_2C "Heatwave spring 2Celcius"
label variable hotmonthspring_175C "Heatwave spring 1.75Celcius"
label variable hotmonthspring_225C "Heatwave spring 2.25Celcius"

label variable hotmonthwinter_2C "Heatwave winter 2Celcius"
label variable hotmonthwinter_175C "Heatwave  winter 1.75Celcius"
label variable hotmonthwinter_225C "Heatwave  winter 2.25Celcius"

label variable hotmonthautumn_2C "Heatwave autumn 2Celcius"
label variable hotmonthautumn_175C "Heatwave autumn 1.75Celcius"
label variable hotmonthautumn_225C "Heatwave  autumn 2.25Celcius"

****** merge with macro dataset

/*
merge 1:1 Territory_ID year using "$github_path/Macrodata_NUTS3.dta" // merge with macro data
*keep if _merge ==3
drop _merge

*** Income regions terciles (1 "Low income" 2 "Middle income" 3 "High income")
xtile Income_group=gdp_per_capita, n(3)
label variable Income_group "1low 2middle 3high income regions"

*** Select time period
keep if year > 1994
drop if year > 2022
save  "Final_data.dta", replace // Final data for analysis 
