#!/bin/bash
#TODO: Add your secure token, because there is no automated way yet to do it
influx bucket create --name water_heating_data --retention 30d
influx auth create --write-bucket water_heating_data --read-bucket water_heating_data --token YOUR_SECURE_TOKEN