const main = function () {

    // .sidebar-title a
    const sidebar_title = document.querySelector(".sidebar-title a");
    if (sidebar_title) {
        sidebar_title.innerHTML = "<img src='images/logo/background_blur_transparent.png' width='100%' height='auto' /><br/>Relatório Metodológico<br/>";
    }

    // .quarto-title h1.title
    const page_title = document.querySelector(".quarto-title h1.title");
    if (page_title && page_title.textContent === "GTFShift: Edição TML") {
        page_title.textContent = "Relatório Metodológico";
    }
}

document.addEventListener('DOMContentLoaded', main, false);