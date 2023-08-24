# gui_casino_simulation.py
import tkinter as tk
from tkinter import ttk
import concurrent.futures
import sim as cs
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
import hashlib
import os

current_directory = os.getcwd()
selected_bet_options = cs.BET_OPTIONS.copy()

def update_label(value, label_var):
    label_var.set(int(float(value)))

def toggle_bet_option(option, var):
    if var.get() == 1:
        selected_bet_options.append(option)
    else:
        selected_bet_options.remove(option)   

def update_and_plot():
    
    cs.NUM_SIMULATIONS = int(num_sims_slider.get())
    cs.NUM_FLIPS = int(num_flips_slider.get())
    cs.START_TREASURY = int(start_treasury_slider.get())
    cs.HOUSE_EDGE = house_edge_slider.get()/100
    cs.NETWORK_COST = network_cost_slider.get()
    cs.BET_OPTIONS = selected_bet_options


    with concurrent.futures.ThreadPoolExecutor() as executor:
        results = list(executor.map(cs.simulate, range(cs.NUM_SIMULATIONS)))

    cs.plot_results( cs.NUM_SIMULATIONS, cs.NUM_FLIPS, cs.START_TREASURY, cs.HOUSE_EDGE, cs.NETWORK_COST, results)

    for widget in plot_frame.winfo_children():
        widget.destroy()

    canvas = FigureCanvasTkAgg(cs.fig, master=plot_frame)  # Create the canvas
    canvas_widget = canvas.get_tk_widget()
    canvas_widget.pack(side=tk.TOP, fill=tk.BOTH, expand=1)
    canvas.draw()

def update_label(slider, label_var):
    label_var.set(int(slider.get()))


def save_plot():
    file_path = save_location_var.get()

    parameter_hash = hashlib.md5(str(cs.NUM_SIMULATIONS + cs.NUM_FLIPS + cs.START_TREASURY + cs.HOUSE_EDGE + cs.NETWORK_COST).encode()).hexdigest()

    # Construct the file name using the hash
    file_name = f"simulation_{parameter_hash}.png"

    # Construct the full path
    file_path = os.path.join(current_directory, file_name)

    if not file_path:
        return  # Don't save if the file path is empty

    if not file_path.endswith('.png'):
        file_path += '.png'  # Append .png extension if not provided

    canvas = cs.fig.canvas
    canvas.print_png(file_path)
    print(f"Plot saved as {file_path}")

def exit_program():
    print("Exiting.")
    root.destroy()
    exit()

root = tk.Tk()
root.title("Casino Simulator")

frame = ttk.Frame(root)
frame.grid(padx=20, pady=20)

# Label Variables for the sliders
num_sims_var = tk.StringVar()
num_flips_var = tk.StringVar()
start_treasury_var = tk.StringVar()
house_edge_var = tk.StringVar()

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
house_edge_slider = tk.Scale(frame, from_=0, to_=100, orient=tk.HORIZONTAL, length=300, command=lambda e: update_label(house_edge_slider, house_edge_var))
house_edge_slider.set(cs.HOUSE_EDGE)
house_edge_slider.grid(row=3, column=1)

ttk.Label(frame, text="Network Cost:").grid(row=4, column=0)
network_cost_slider = tk.Scale(frame, from_=0.1, to_=5, orient=tk.HORIZONTAL, length=300, resolution=0.1)
network_cost_slider.set(cs.NETWORK_COST)
network_cost_slider.grid(row=4, column=1)

bet_option_vars = []
for i, option in enumerate(cs.BET_OPTIONS):
    var = tk.IntVar(value=(option in selected_bet_options))
    bet_option_vars.append(var)
    ttk.Checkbutton(frame, text=f"${option}", variable=var, command=lambda o=option, v=var: toggle_bet_option(o, v)).grid(row=8, column=i, sticky=tk.W)
for i in range(len(cs.BET_OPTIONS)):
    frame.grid_columnconfigure(i, weight=1)


plot_frame = ttk.Frame(root)
plot_frame.grid(row=6, columnspan=3, padx=20, pady=20)


save_frame = ttk.Frame(root)
save_frame.grid(row=7, columnspan=3, padx=20, pady=10)

save_location_var = tk.StringVar(value=current_directory)  # Default save location
ttk.Label(save_frame, text="Save:").grid(row=0, column=0, sticky=tk.W)
save_location_entry = ttk.Entry(save_frame, textvariable=save_location_var)
save_location_entry.grid(row=0, column=1, padx=5)

save_button = ttk.Button(save_frame, text="Save Plot", command=save_plot)
save_button.grid(row=0, column=2, padx=5)

run_button = ttk.Button(root, text="Run", command=update_and_plot)
run_button.grid(row=8, column=0, padx=10, pady=20)

exit_button = ttk.Button(root, text="Exit", command=exit_program)
exit_button.grid(row=9, columnspan=2, pady=10)


root.mainloop()

