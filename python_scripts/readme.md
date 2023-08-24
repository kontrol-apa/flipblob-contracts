# flipblob Simulation with Python

This repository contains Python scripts for simulating flipblob and a GUI application to visualize the simulation results and to fine tune parameters.

## Overview

- `sim.py`: This script defines a casino simulation model. It simulates a casino game with various parameters such as number of simulations, number of flips, starting treasury, house edge, and network cost. It generates simulation results, including treasury balances, wins, losses, and more.

- `gui_sim.py`: This script provides a graphical user interface (GUI) for interacting with the casino simulation. It uses the `tkinter` library to create a user-friendly interface where you can adjust simulation parameters, run simulations, plot results, and save plots.

## Features

- Simulate casino games with customizable parameters.
- Visualize simulation results with interactive plots.
- Save simulation result plots as image files.

## Prerequisites

- Python 3.x

## Installation

Install the required libraries using the following command:

```bash
pip install matplotlib
```

## Usage

```bash
python gui_sim.py
