#!/usr/bin/env python

# Script to build a MacOS X Application from callmungereasygui.py
# Just run:
# python buildapp.py build

from bundlebuilder import buildapp

buildapp(
        name = "EasyMunger",
        mainprogram = "callmungereasygui.py",
)
