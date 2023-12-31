import random
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties

# fig = plt.figure()

NUM_SIMULATIONS = 100
NUM_FLIPS = 10000
START_TREASURY = 5000
MAX_BET = 100
BET_OPTIONS = [5, 10, 20, 50, 100]
HOUSE_EDGE = 5
NETWORK_COST = 0.5

def simulate(_):
    treasury = START_TREASURY
    wins, losses, volumes = 0, 0, 0
    lowest_balance = START_TREASURY
    balances = [START_TREASURY]
     
    for _ in range(NUM_FLIPS):
        bet = random.choice(BET_OPTIONS)
        volumes += bet
        if bet > treasury:
            lowest_balance = 0
            break
        coin_flip = random.choice([True, False]) # True is win, False is lose
        if coin_flip:
            payout = bet * (1 - HOUSE_EDGE)
            treasury -= payout
            wins += 1
        else:
            treasury += bet
            losses += 1
        treasury -= NETWORK_COST
        balances.append(treasury)
        lowest_balance = min(lowest_balance, treasury)

        
    return balances, lowest_balance, wins, losses, volumes, (treasury - START_TREASURY)



def plot_results(NUM_SIMULATIONS, NUM_FLIPS, START_TREASURY, HOUSE_EDGE, NETWORK_COST, results):

    global fig  # Declare fig as global so it can be accessed from outside the function
    # Unpack the results into their individual components
    balances, lowest_balances, wins, losses, volumes, profits = zip(*results)

    bankruptcy_count = sum(1 for balance in lowest_balances if balance <= 0)
    # Average balances over all simulations
    average_results = [sum(x) / NUM_SIMULATIONS for x in zip(*balances)]
    average_volume = sum(volumes) / NUM_SIMULATIONS 
    average_profit = sum(profits) / NUM_SIMULATIONS 


    fig, axs = plt.subplots(4, 1, figsize=(5,10))

    # Average treasury balance over time
    axs[0].plot(average_results, color="blue", label="Average Treasury")
    axs[0].set_title(f"Average Treasury Balance Over Time\n({NUM_SIMULATIONS} Parallel Simulations, {NUM_FLIPS} Plays Each)")
    axs[0].set_xlabel("Flips")
    axs[0].set_ylabel("Balance")
    axs[0].legend()

    # Lowest Treasury per Run
    axs[1].scatter(range(NUM_SIMULATIONS), lowest_balances, color="red", label="Lowest Treasury per Run")
    axs[1].set_title(f"Lowest Treasury per Run\n({NUM_SIMULATIONS} Parallel Simulations, {NUM_FLIPS} Plays Each)")
    axs[1].set_xlabel("Simulation Run")
    axs[1].set_ylabel("Lowest Balance")

    # Wins and Losses per Run
    axs[2].bar(range(NUM_SIMULATIONS), wins, color="green", label="Wins")
    axs[2].bar(range(NUM_SIMULATIONS), losses, color="red", label="Losses", bottom=wins)
    axs[2].set_title(f"Wins and Losses per Run\n({NUM_SIMULATIONS} Parallel Simulations, {NUM_FLIPS} Plays Each)")
    axs[2].set_xlabel("Simulation Run")
    axs[2].set_ylabel("Count")
    axs[2].legend()


    font = FontProperties()
    font.set_family('monospace')
    font.set_size(9)
    font.set_weight('bold')

    axs[3].text(0.5, 0.9, f'Starting Treasury: ${START_TREASURY:.0f},  Bet Options: {BET_OPTIONS}', 
                ha='center', va='center', fontproperties=font)
    axs[3].text(0.5, 0.8, f'House Edge: {HOUSE_EDGE*100}%,  Network Cost Per TX: ${NETWORK_COST}', 
                ha='center', va='center', fontproperties=font)
    axs[3].axis('off') # Turn off axis
    font.set_size(14)
    axs[3].text(0.5, 0.6, f'Average Volume: ${average_volume:.0f}', 
                ha='center', va='center', fontproperties=font)
    axs[3].text(0.5, 0.4, f'Bankruptcy: {bankruptcy_count:.0f}', 
                ha='center', va='center', fontproperties=font)
    axs[3].text(0.5, 0.2, f'Bankruptcy Perc: {bankruptcy_count/ int(NUM_SIMULATIONS) * 100}', 
                ha='center', va='center', fontproperties=font)
    axs[3].text(0.5, 0.0, f'Average Profit: ${average_profit:.0f}', 
                ha='center', va='center', fontproperties=font)



    plt.tight_layout()



    # TOTAL VOLUME
    # TOTAL PROFIT