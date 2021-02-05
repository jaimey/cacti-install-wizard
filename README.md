# Installation wizard for Cacti on Ubuntu

This script downloads all dependencies and install the latest version of cacti.

## Description

#### What is Cacti?

![Cacti](https://www.cacti.net/images/cacti_promo_main.png)

Cacti is a complete frontend to RRDTool, it stores all of the necessary information to create graphs and populate them with data in a MySQL database. The frontend is completely PHP driven. Along with being able to maintain Graphs, Data Sources, and Round Robin Archives in a database, cacti handles the data gathering. There is also SNMP support for those used to creating traffic graphs with MRTG.

## Usage

```
wget  https://raw.githubusercontent.com/jaimey/cacti-install-wizard/main/cacti_install.sh
chmod +x cacti_install.sh
sudo ./cacti_install.sh
```