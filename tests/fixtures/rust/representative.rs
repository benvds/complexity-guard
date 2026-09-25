pub fn classify(input: Option<i32>) -> i32 {
    let Some(value) = input else { return 0 };
    match value {
        0 | 1 => 1,
        n if n > 10 => 2,
        _ => 3,
    }
}

struct Counter;

impl Counter {
    pub fn tick(&self, value: i32) -> i32 {
        if value > 0 && value < 10 {
            value + 1
        } else {
            0
        }
    }
}

trait Reset {
    fn required(&self);
    fn provided(&self) -> bool {
        false
    }
}

impl Reset for Counter {
    fn required(&self) {}
}

fn with_closure() -> i32 {
    let double = |x: i32| x * 2;
    double(2)
}

fn propagate(value: Result<i32, ()>) -> Result<i32, ()> {
    let n = value?;
    Ok(n)
}

#[cfg(test)]
fn conditional() -> bool {
    true
}
