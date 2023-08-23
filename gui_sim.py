# gui_casino_simulation.py

import tkinter as tk
from tkinter import ttk
import concurrent.futures
import sim as cs
def update_label(value, label_var):
    label_var.set(int(float(value)))
    
def update_and_plot():
    
    cs.NUM_SIMULATIONS = int(num_sims_slider.get())
    cs.NUM_FLIPS = int(num_flips_slider.get())
    cs.START_TREASURY = int(start_treasury_slider.get())
    cs.HOUSE_EDGE = house_edge_slider.get()
    cs.NETWORK_COST = network_cost_slider.get()
    

    with concurrent.futures.ThreadPoolExecutor() as executor:
        results = list(executor.map(cs.simulate, range(cs.NUM_SIMULATIONS)))

    cs.plot_results( cs.NUM_SIMULATIONS, cs.NUM_FLIPS, cs.START_TREASURY, cs.HOUSE_EDGE, cs.NETWORK_COST, results)

def update_label(slider, label_var):
    label_var.set(int(slider.get()))

root = tk.Tk()
root.title("Casino Simulator")

frame = ttk.Frame(root)
frame.grid(padx=20, pady=20)

# Label Variables for the sliders
num_sims_var = tk.StringVar()
num_flips_var = tk.StringVar()
start_treasury_var = tk.StringVar()

# GUI Components
ttk.Label(frame, text="Number of Simulations:").grid(row=0, column=0, sticky=tk.W)
num_sims_slider = ttk.Scale(frame, from_=10, to_=500, orient=tk.HORIZONTAL, length=300, command=lambda e: update_label(num_sims_slider, num_sims_var))
num_sims_slider.set(cs.NUM_SIMULATIONS)
num_sims_slider.grid(row=0, column=1)
ttk.Label(frame, textvariable=num_sims_var).grid(row=0, column=2)
num_sims_var.set(cs.NUM_SIMULATIONS)

ttk.Label(frame, text="Number of Flips:").grid(row=1, column=0, sticky=tk.W)
num_flips_slider = ttk.Scale(frame, from_=1000, to_=50000, orient=tk.HORIZONTAL, length=300, command=lambda e: update_label(num_flips_slider, num_flips_var))
num_flips_slider.set(cs.NUM_FLIPS)
num_flips_slider.grid(row=1, column=1)
ttk.Label(frame, textvariable=num_flips_var).grid(row=1, column=2)
num_flips_var.set(cs.NUM_FLIPS)

ttk.Label(frame, text="Starting Treasury:").grid(row=2, column=0, sticky=tk.W)
start_treasury_slider = ttk.Scale(frame, from_=1000, to_=20000, orient=tk.HORIZONTAL, length=300, command=lambda e: update_label(start_treasury_slider, start_treasury_var))
start_treasury_slider.set(cs.START_TREASURY)
start_treasury_slider.grid(row=2, column=1)
ttk.Label(frame, textvariable=start_treasury_var).grid(row=2, column=2)
start_treasury_var.set(cs.START_TREASURY)

ttk.Label(frame, text="House Edge:").grid(row=3, column=0)
house_edge_slider = tk.Scale(frame, from_=0.01, to_=0.1, orient=tk.HORIZONTAL, length=300, resolution=0.01)
house_edge_slider.set(cs.HOUSE_EDGE)
house_edge_slider.grid(row=3, column=1)

ttk.Label(frame, text="Network Cost:").grid(row=4, column=0)
network_cost_slider = tk.Scale(frame, from_=0.1, to_=5, orient=tk.HORIZONTAL, length=300, resolution=0.1)
network_cost_slider.set(cs.NETWORK_COST)
network_cost_slider.grid(row=4, column=1)

run_button = ttk.Button(frame, text="Run Simulation & Plot", command=update_and_plot)
run_button.grid(row=5, columnspan=2, pady=20)

root.mainloop()

