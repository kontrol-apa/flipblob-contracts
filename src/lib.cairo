mod flip {
    mod flipblob;
}

mod erc20 {
    mod erc20;
}

#[cfg(test)]
mod tests {
    mod fork_testing;
    mod test_contract;

    mod test_utils {
        mod common_fork;
        mod common;
    }
}