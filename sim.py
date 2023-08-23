import random
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
import concurrent.futures

NUM_SIMULATIONS = 100
NUM_FLIPS = 10000
START_TREASURY = 10000
MAX_BET = 100
BET_OPTIONS = [5, 10, 20, 50, 100]
HOUSE_EDGE = 0.05
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
        
    return balances, lowest_balance, wins, losses, volumes

with concurrent.futures.ThreadPoolExecutor() as executor:
    results = list(executor.map(simulate, range(NUM_SIMULATIONS)))

# Unpack the results into their individual components
balances, lowest_balances, wins, losses, volumes = zip(*results)

# Average balances over all simulations
average_results = [sum(x) / NUM_SIMULATIONS for x in zip(*balances)]
average_volume = sum(volumes) / NUM_SIMULATIONS 


fig, axs = plt.subplots(4, 1, figsize=(10,15))

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
axs[1].legend()

# Wins and Losses per Run
axs[2].bar(range(NUM_SIMULATIONS), wins, color="green", label="Wins")
axs[2].bar(range(NUM_SIMULATIONS), losses, color="red", label="Losses", bottom=wins)
axs[2].set_title(f"Wins and Losses per Run\n({NUM_SIMULATIONS} Parallel Simulations, {NUM_FLIPS} Plays Each)")
axs[2].set_xlabel("Simulation Run")
axs[2].set_ylabel("Count")
axs[2].legend()


font = FontProperties()
font.set_family('monospace')
font.set_size(14)
font.set_weight('bold')
# Volume per Run
axs[3].axis('off') # Turn off axis
axs[3].text(0.5, 0.5, f'Average Volume: ${average_volume:.0f}', 
            ha='center', va='center', fontproperties=font)



plt.tight_layout()
plt.show()



# TOTAL VOLUME
# TOTAL PROFIT