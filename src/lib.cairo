mod flip;
mod merc20;

#[cfg(test)]
mod tests {
    mod fork_testing;
    mod test_contract;

    mod test_utils {
        mod common_fork;
        mod common;
    }
}